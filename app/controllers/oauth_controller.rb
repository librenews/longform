class OauthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:client_metadata]
  skip_before_action :verify_authenticity_token, only: [:client_metadata]
  
  def client_metadata
    app_url = Rails.application.config.app_url
    
    # Ensure keys exist
    unless OmniAuth::Atproto::KeyManager.keys_exist?
      OmniAuth::Atproto::KeyManager.generate_keys
    end
    
    # Set specific headers for OAuth client metadata
    response.headers['Content-Type'] = 'application/json'
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    
    render json: {
      client_id: "#{app_url}/oauth/client-metadata.json",
      application_type: "web",
      client_name: "Longform",
      client_uri: app_url,
      dpop_bound_access_tokens: true,
      grant_types: [
        "authorization_code",
        "refresh_token"
      ],
      redirect_uris: [
        "#{app_url}/auth/atproto/callback"
      ],
      response_types: [
        "code"
      ],
      scope: "atproto transition:generic",
      token_endpoint_auth_method: "private_key_jwt",
      token_endpoint_auth_signing_alg: "ES256",
      jwks: {
        keys: [OmniAuth::Atproto::KeyManager.current_jwk]
      }
    }
  end
end
