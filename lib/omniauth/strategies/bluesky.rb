require 'omniauth'
require 'faraday'
require 'json'

module OmniAuth
  module Strategies
    class Bluesky
      include OmniAuth::Strategy

      option :name, :bluesky
      option :title, 'Bluesky'
      
      # AT Protocol endpoints
      option :pds_url, 'https://bsky.social'
      option :service_endpoint, 'https://bsky.social'
      
      # Custom fields for AT Protocol
      args [:client_id, :client_secret]
      
      uid { raw_info['did'] }
      
      info do
        {
          handle: raw_info['handle'],
          email: raw_info['email'],
          name: profile_info['displayName'],
          nickname: raw_info['handle'],
          image: profile_info['avatar'],
          description: profile_info['description'],
          did: raw_info['did']
        }
      end
      
      extra do
        {
          raw_info: raw_info,
          profile: profile_info,
          session: session_info,
          pds_url: options.pds_url
        }
      end
      
      credentials do
        {
          token: session_info['accessJwt'],
          refresh_token: session_info['refreshJwt'],
          expires_at: jwt_expires_at,
          expires: true
        }
      end

      # The request phase redirects to a custom login form
      def request_phase
        redirect "/auth/#{name}/login"
      end

      # Handle the callback phase
      def callback_phase
        identifier = request.params['identifier']
        password = request.params['password']
        
        return fail!(:missing_credentials) if identifier.blank? || password.blank?
        
        begin
          # Step 1: Resolve the identifier to get the PDS URL
          resolved_identity = resolve_identifier(identifier)
          return fail!(:invalid_identifier) unless resolved_identity
          
          # Step 2: Create session with the resolved PDS
          create_session(resolved_identity, password)
          return fail!(:invalid_credentials) unless @session_data
          
          # Step 3: Get profile information
          fetch_profile_info
          
          super
        rescue => e
          Rails.logger.error "Bluesky OAuth error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          fail!(:authentication_error, e)
        end
      end

      private

      def resolve_identifier(identifier)
        # Handle different identifier formats
        if identifier.include?('@')
          # Email-like handle
          handle = identifier
        elsif identifier.include('.')
          # Domain-like handle
          handle = identifier
        else
          # Simple handle - add .bsky.social
          handle = "#{identifier}.bsky.social"
        end

        # Resolve handle to DID and PDS
        begin
          response = connection.get("/.well-known/atproto-did") do |req|
            req.headers['Host'] = handle.split('@').last || handle
          end

          if response.success?
            # Parse DID document to get PDS endpoint
            did_doc = JSON.parse(response.body)
            {
              handle: handle,
              did: did_doc['id'],
              pds_url: extract_pds_url(did_doc) || options.pds_url
            }
          else
            # Fallback to directory lookup
            directory_resolve(handle)
          end
        rescue
          # Final fallback - use default PDS
          {
            handle: handle,
            did: nil, # Will be filled in after authentication
            pds_url: options.pds_url
          }
        end
      end

      def extract_pds_url(did_doc)
        # Extract PDS URL from DID document
        services = did_doc['service'] || []
        pds_service = services.find { |s| s['type'] == 'AtprotoPersonalDataServer' }
        pds_service&.dig('serviceEndpoint')
      end

      def directory_resolve(handle)
        # Try to resolve through AT Protocol directory
        response = connection(base_url: 'https://plc.directory').get("/#{handle}")
        
        if response.success?
          did_doc = JSON.parse(response.body)
          {
            handle: handle,
            did: did_doc['id'],
            pds_url: extract_pds_url(did_doc) || options.pds_url
          }
        else
          nil
        end
      rescue
        nil
      end

      def create_session(identity, password)
        endpoint = identity[:pds_url] || options.pds_url
        
        response = connection(base_url: endpoint).post('/xrpc/com.atproto.server.createSession') do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = {
            identifier: identity[:handle],
            password: password
          }.to_json
        end

        if response.success?
          @session_data = JSON.parse(response.body)
          @pds_url = endpoint
          true
        else
          Rails.logger.error "Session creation failed: #{response.status} #{response.body}"
          false
        end
      end

      def fetch_profile_info
        return unless @session_data

        response = connection(base_url: @pds_url).get('/xrpc/com.atproto.repo.getRecord') do |req|
          req.headers['Authorization'] = "Bearer #{@session_data['accessJwt']}"
          req.params = {
            repo: @session_data['did'],
            collection: 'app.bsky.actor.profile',
            rkey: 'self'
          }
        end

        if response.success?
          record_data = JSON.parse(response.body)
          @profile_data = record_data.dig('value') || {}
        else
          @profile_data = {}
        end
      end

      def raw_info
        @session_data || {}
      end

      def profile_info
        @profile_data || {}
      end

      def session_info
        @session_data || {}
      end

      def jwt_expires_at
        # Parse JWT to get expiration
        return nil unless session_info['accessJwt']
        
        begin
          # Simple JWT parsing (without verification for expiration only)
          payload = session_info['accessJwt'].split('.')[1]
          decoded = Base64.decode64(payload + '==') # Add padding
          jwt_payload = JSON.parse(decoded)
          Time.at(jwt_payload['exp']) if jwt_payload['exp']
        rescue
          # Default to 1 hour from now if we can't parse
          1.hour.from_now
        end
      end

      def connection(base_url: nil)
        Faraday.new(url: base_url || options.pds_url) do |conn|
          conn.request :json
          conn.response :json, content_type: /\bjson$/
          conn.adapter Faraday.default_adapter
          conn.options.timeout = 10
          conn.options.open_timeout = 5
        end
      end
    end
  end
end

# Custom route for login form
Rails.application.routes.prepend do
  get '/auth/bluesky/login', to: 'sessions#bluesky_login'
  post '/auth/bluesky/callback', to: 'sessions#omniauth'
end
