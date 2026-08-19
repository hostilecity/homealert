Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication
  get  "login",  to: "sessions#new",     as: :login
  post "logout", to: "sessions#destroy", as: :logout

  get  "/auth/:provider/callback", to: "omniauth_callbacks#google_oauth2"
  get  "/auth/failure",            to: "sessions#failure"

  # Authenticated root
  root "dashboard#index"
end
