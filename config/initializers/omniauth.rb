Rails.application.config.middleware.use OmniAuth::Builder do
  setting = Setting.first
  provider :twitter, setting.twitter_consumer_key, setting.twitter_consumer_secret
end