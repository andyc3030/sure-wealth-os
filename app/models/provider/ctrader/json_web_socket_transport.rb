# frozen_string_literal: true

require "json"
require "openssl"
require "socket"
require "timeout"
require "websocket/driver"

class Provider::Ctrader::JsonWebSocketTransport
  PORT = 5036
  HEARTBEAT_PAYLOAD_TYPE = 51
  TOKEN_INVALIDATED_PAYLOAD_TYPE = 2147
  HEARTBEAT_INTERVAL = 10
  DEFAULT_OPEN_TIMEOUT = 10
  DEFAULT_RESPONSE_TIMEOUT = 30

  attr_reader :environment

  def initialize(environment:, open_timeout: DEFAULT_OPEN_TIMEOUT, response_timeout: DEFAULT_RESPONSE_TIMEOUT)
    @environment = environment.to_s
    raise ArgumentError, "environment must be demo or live" unless %w[demo live].include?(@environment)

    @open_timeout = open_timeout
    @response_timeout = response_timeout
    @state_mutex = Mutex.new
    @open_condition = ConditionVariable.new
    @pending_mutex = Mutex.new
    @pending = {}
    @socket_write_mutex = Mutex.new
    @send_mutex = Mutex.new
    @closed = false
  end

  def url
    "wss://#{host}:#{PORT}"
  end

  def call(payload_type:, payload:, client_msg_id:)
    raise ArgumentError, "client_msg_id is required" if client_msg_id.blank?

    connect!
    authentication_error = @state_mutex.synchronize { @authentication_error }
    raise authentication_error if authentication_error

    queue = Queue.new

    @pending_mutex.synchronize do
      raise Provider::Ctrader::Error, "duplicate cTrader clientMsgId" if @pending.key?(client_msg_id)

      @pending[client_msg_id] = queue
    end

    envelope = {
      "clientMsgId" => client_msg_id,
      "payloadType" => Integer(payload_type),
      "payload" => payload.to_h
    }

    @send_mutex.synchronize do
      raise Provider::Ctrader::Error, "cTrader WebSocket is closed" if closed?

      @driver.text(JSON.generate(envelope))
    end

    result = Timeout.timeout(@response_timeout) { queue.pop }
    raise result if result.is_a?(Exception)

    result
  rescue Timeout::Error
    raise Provider::Ctrader::Error, "cTrader response timed out"
  ensure
    @pending_mutex.synchronize { @pending.delete(client_msg_id) } if client_msg_id.present?
  end

  def close
    @state_mutex.synchronize do
      return if @closed

      @closed = true
    end

    begin
      @driver&.close
    rescue StandardError
      nil
    end

    @heartbeat_thread&.kill
    @reader_thread&.kill
    @socket&.close
    fail_pending!(Provider::Ctrader::Error.new("cTrader connection closed"))
    true
  end

  # Called by websocket-driver when it emits handshake/frame bytes.
  def write(data)
    @socket_write_mutex.synchronize do
      raise Provider::Ctrader::Error, "cTrader socket is unavailable" unless @socket

      @socket.write(data)
    end
  end

  private

    attr_reader :open_timeout, :response_timeout

    def host
      environment == "live" ? "live.ctraderapi.com" : "demo.ctraderapi.com"
    end

    def connect!
      @state_mutex.synchronize do
        return if @open
        raise Provider::Ctrader::Error, "cTrader WebSocket transport is closed" if @closed

        open_socket!
        configure_driver!
        start_reader!
        @driver.start

        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + open_timeout
        until @open
          raise @connection_error if @connection_error

          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise Provider::Ctrader::Error, "cTrader WebSocket handshake timed out" if remaining <= 0

          @open_condition.wait(@state_mutex, remaining)
          raise @connection_error if @connection_error
        end

        start_heartbeat!
      end
    end

    def open_socket!
      tcp = Socket.tcp(host, PORT, connect_timeout: open_timeout)
      context = OpenSSL::SSL::SSLContext.new
      context.set_params
      ssl = OpenSSL::SSL::SSLSocket.new(tcp, context)
      ssl.hostname = host if ssl.respond_to?(:hostname=)
      ssl.sync_close = true
      Timeout.timeout(open_timeout) { ssl.connect }
      @socket = ssl
    rescue StandardError => e
      raise Provider::Ctrader::Error, "cTrader connection failed: #{e.class}"
    end

    def configure_driver!
      @driver = WebSocket::Driver.client(self)
      @driver.on(:open) do
        @state_mutex.synchronize do
          @open = true
          @open_condition.broadcast
        end
      end
      @driver.on(:message) { |event| handle_message(event.data) }
      @driver.on(:error) { |event| connection_failed!(event.message) }
      @driver.on(:close) { connection_failed!("cTrader WebSocket closed") unless closed? }
    end

    def start_reader!
      @reader_thread = Thread.new do
        loop do
          data = @socket.readpartial(16_384)
          @driver.parse(data)
        end
      rescue EOFError, IOError, OpenSSL::SSL::SSLError, SystemCallError => e
        connection_failed!("cTrader socket reader stopped: #{e.class}") unless closed?
      end
      @reader_thread.abort_on_exception = false
    end

    def start_heartbeat!
      return if @heartbeat_thread&.alive?

      @heartbeat_thread = Thread.new do
        loop do
          sleep HEARTBEAT_INTERVAL
          break if closed?

          @send_mutex.synchronize do
            @driver.text(JSON.generate(
              "payloadType" => HEARTBEAT_PAYLOAD_TYPE,
              "payload" => {}
            ))
          end
        end
      rescue StandardError => e
        connection_failed!("cTrader heartbeat failed: #{e.class}") unless closed?
      end
      @heartbeat_thread.abort_on_exception = false
    end

    def handle_message(data)
      message = JSON.parse(data.to_s)
      payload_type = message["payloadType"].to_i
      return if payload_type == HEARTBEAT_PAYLOAD_TYPE

      if payload_type == TOKEN_INVALIDATED_PAYLOAD_TYPE
        authentication_failed!("cTrader account access token was invalidated")
        return
      end

      client_msg_id = message["clientMsgId"].presence
      if client_msg_id
        queue = @pending_mutex.synchronize { @pending[client_msg_id] }
        queue << message if queue
      elsif error_payload?(message)
        fail_pending!(Provider::Ctrader::Error.new("cTrader returned an uncorrelated error"))
      end
    rescue JSON::ParserError
      fail_pending!(Provider::Ctrader::Error.new("cTrader returned invalid JSON"))
    end

    def error_payload?(message)
      message["payloadType"].to_i.in?([ 50, 2142 ]) ||
        message.dig("payload", "errorCode").present?
    end

    def authentication_failed!(message)
      error = Provider::Ctrader::AuthenticationError.new(message)

      @state_mutex.synchronize do
        @authentication_error ||= error
      end
      fail_pending!(error)
    end

    def connection_failed!(message)
      error = Provider::Ctrader::Error.new(message)

      @state_mutex.synchronize do
        @connection_error ||= error
        @open = false
        @open_condition.broadcast
      end
      fail_pending!(error)
    end

    def fail_pending!(error)
      queues = @pending_mutex.synchronize { @pending.values.dup }
      queues.each { |queue| queue << error }
    end

    def closed?
      @state_mutex.synchronize { @closed }
    end
end
