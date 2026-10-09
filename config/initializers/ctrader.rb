Rails.application.configure do
  config.x.ctrader = ActiveSupport::OrderedOptions.new
  config.x.ctrader.client_id = ENV["CTRADER_OPEN_API_CLIENT_ID"]
  config.x.ctrader.client_secret = ENV["CTRADER_OPEN_API_CLIENT_SECRET"]
end
