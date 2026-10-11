# frozen_string_literal: true

class Provider::Ctrader
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class AuthenticationError < Error; end
  class PermissionError < Error; end

  AUTHORIZE_URL = "https://id.ctrader.com/my/settings/openapi/grantingaccess/".freeze
  TOKEN_URL = "https://openapi.ctrader.com/apps/token".freeze
  REQUIRED_SCOPE = "accounts".freeze
  FORBIDDEN_SCOPE = "trading".freeze

  class << self
    def configured?
      client_id.present? && client_secret.present?
    end

    def client_id
      Rails.configuration.x.ctrader&.client_id
    end

    def client_secret
      Rails.configuration.x.ctrader&.client_secret
    end

    def authorize_url(redirect_uri:)
      raise ConfigurationError, "cTrader Open API is not configured" unless configured?
      raise ArgumentError, "redirect_uri is required" if redirect_uri.blank?

      params = {
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: REQUIRED_SCOPE,
        product: "web"
      }

      "#{AUTHORIZE_URL}?#{params.to_query}"
    end

    def exchange_code(code:, redirect_uri:)
      raise ArgumentError, "authorization code is required" if code.blank?
      raise ArgumentError, "redirect_uri is required" if redirect_uri.blank?

      token_request(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri
      )
    end

    def refresh_tokens(refresh_token:)
      raise ArgumentError, "refresh_token is required" if refresh_token.blank?

      token_request(
        grant_type: "refresh_token",
        refresh_token: refresh_token
      )
    end

    private

      def token_request(params)
        raise ConfigurationError, "cTrader Open API is not configured" unless configured?

        response = token_connection.get(TOKEN_URL) do |request|
          request.params.update(
            params.merge(client_id: client_id, client_secret: client_secret)
          )
          request.headers["Accept"] = "application/json"
        end

        payload = JSON.parse(response.body.presence || "{}")
        unless response.success? && payload["errorCode"].blank?
          raise AuthenticationError,
                "cTrader token request failed: #{payload["errorCode"].presence || "HTTP #{response.status}"}"
        end
        if payload["accessToken"].blank? || payload["refreshToken"].blank?
          raise AuthenticationError, "cTrader token response is missing required tokens"
        end

        payload
      rescue JSON::ParserError
        raise AuthenticationError, "cTrader token response is not valid JSON"
      end

      def token_connection
        @token_connection ||= Faraday.new do |faraday|
          faraday.options.timeout = 30
          faraday.options.open_timeout = 10
        end
      end
  end
end
