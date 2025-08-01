require_relative '../../lib/omniauth/atproto/key_manager'

Rails.application.config.middleware.use OmniAuth::Builder do
  app_url = Rails.application.config.respond_to?(:app_url) ? Rails.application.config.app_url : "http://localhost:3000"
  
  provider(:atproto,
    "#{app_url}/oauth/client-metadata.json",
    nil,
    client_options: {
        site: "https://bsky.social",
        authorize_url: "https://bsky.social/oauth/authorize",
        token_url: "https://bsky.social/oauth/token"
    },
    scope: "atproto transition:generic transition:chat.bsky",
    private_key: OmniAuth::Atproto::KeyManager.current_private_key,
    client_jwk: OmniAuth::Atproto::KeyManager.current_jwk,
    setup: lambda { |env|
      # Store the handle parameter in session for later use
      request = Rack::Request.new(env)
      handle = request.params['handle']
      if handle.present?
        env['rack.session']['pending_handle'] = handle
      end
      Rails.logger.info "[OmniAuth] Bluesky OAuth authorize_url: https://bsky.social/oauth/authorize"
      Rails.logger.info "[OmniAuth] Bluesky OAuth scope: atproto transition:generic transition:chat.bsky"
    })
end

# Configure OmniAuth settings
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

# Configure CSRF protection
OmniAuth.config.allowed_request_methods = [:get, :post]
OmniAuth.config.silence_get_warning = true
