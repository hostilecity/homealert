google_client_id     = ENV.fetch("GOOGLE_CLIENT_ID", "")
google_client_secret = ENV.fetch("GOOGLE_CLIENT_SECRET", "")

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    google_client_id,
    google_client_secret,
    scope: "email,profile"
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning = true
