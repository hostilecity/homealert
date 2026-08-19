Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication
  get  "login",  to: "sessions#new",     as: :login
  post "logout", to: "sessions#destroy", as: :logout

  get  "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  get  "/auth/failure",            to: "sessions#failure"

  # Public pages
  get "privacy", to: "pages#privacy", as: :privacy

  # Authenticated root
  root "dashboard#index"
end
