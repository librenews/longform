Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA files
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # OAuth client metadata (dynamic)
  get "oauth/client-metadata.json", to: "oauth#client_metadata"
  get "oauth/jwks.json", to: "oauth#jwks"
  
  # OAuth required pages
  get "terms", to: "pages#terms"
  get "privacy", to: "pages#privacy"

  # Root route
  root "home#index"

  # Authentication routes
  get "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/failure", to: "sessions#failure"
  delete "/sign_out", to: "sessions#destroy", as: :sign_out

  # Dashboard
  get "/dashboard", to: "dashboard#index", as: :dashboard

  # User profiles
  get "/profile/:handle", to: "profiles#show", as: :profile, constraints: { handle: /[^\/]+/ }

  # Posts
  resources :posts do
    member do
      patch :publish
      patch :unpublish
      patch :archive
      patch :unarchive
    end
  end

  # Records browser for AT Protocol inspection
  resources :records, only: [:index, :show] do
    collection do
      get 'collection/:collection_name', to: 'records#collection', as: 'collection', constraints: { collection_name: /[^\/]+/ }
    end
  end

  # Health check for self-hosting
  get "/health", to: "application#health"
end
