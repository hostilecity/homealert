Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication
  get  "login",  to: "sessions#new",     as: :login
  post "logout", to: "sessions#destroy", as: :logout

  get  "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  get  "/auth/failure",                to: "sessions#failure"

  # Webhooks (public, no authentication)
  namespace :webhooks do
    post "reolink", to: "reolink#create"
  end

  # Events feed (AJAX, authenticated)
  get "events/feed", to: "events#feed", as: :events_feed

  # Push subscriptions
  resources :push_subscriptions, only: %i[create destroy]

  # Settings
  get   "settings",                             to: "settings#index",                        as: :settings
  patch "settings/notification_preferences",    to: "settings#update_notification_preferences", as: :settings_notification_preferences

  # PWA
  get "manifest",       to: "rails/pwa#manifest",      as: :pwa_manifest
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker

  # Public pages
  get "privacy", to: "pages#privacy", as: :privacy

  # Authenticated root
  root "dashboard#index"
end
