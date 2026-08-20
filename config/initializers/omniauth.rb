return if Rails.env.test?

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV.fetch("GOOGLE_CLIENT_ID"),
           ENV.fetch("GOOGLE_CLIENT_SECRET"),
           scope: "email,profile"
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning = true
