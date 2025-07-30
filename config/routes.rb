Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA files
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # OAuth client metadata (dynamic)
  get "oauth/client-metadata.json", to: "oauth#client_metadata"

  # Root route
  root "home#index"

  # Authentication routes
  get "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/failure", to: "sessions#failure"
  delete "/sign_out", to: "sessions#destroy", as: :sign_out

  # Dashboard
  get "/dashboard", to: "dashboard#index", as: :dashboard

  # Posts
  resources :posts do
    member do
      patch :publish
      patch :unpublish
      patch :archive
      patch :unarchive
    end
  end

  # Health check for self-hosting
  get "/health", to: "application#health"
end
