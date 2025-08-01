class BlueskyRecordReader
  def initialize(user)
    @user = user
    @dpop_nonce = nil
  end

  def list_records(collection = 'com.whtwnd.blog.entry', limit = 50)
    return { success: false, error: "User not authenticated with Bluesky" } unless @user.has_valid_bluesky_token?

    begin
      result = fetch_records(collection, limit)
      
      if result[:success]
        Rails.logger.info "Successfully fetched #{result[:records].length} records from #{collection}"
        { success: true, records: result[:records], cursor: result[:cursor] }
      else
        Rails.logger.error "Failed to fetch records: #{result[:error]}"
        { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "Error fetching records: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  def get_record(at_uri)
    return { success: false, error: "User not authenticated with Bluesky" } unless @user.has_valid_bluesky_token?

    begin
      # Parse AT URI to extract repo and rkey
      # Format: at://did:plc:xxx/collection/rkey
      uri_parts = at_uri.match(%r{^at://([^/]+)/([^/]+)/([^/]+)$})
      return { success: false, error: "Invalid AT URI format" } unless uri_parts

      repo = uri_parts[1]
      collection = uri_parts[2]
      rkey = uri_parts[3]

      result = fetch_single_record(repo, collection, rkey)
      
      if result[:success]
        Rails.logger.info "Successfully fetched record: #{at_uri}"
        { success: true, record: result[:record], uri: result[:uri], cid: result[:cid] }
      else
        Rails.logger.error "Failed to fetch record #{at_uri}: #{result[:error]}"
        { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "Error fetching record #{at_uri}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def list_all_collections
    return { success: false, error: "User not authenticated with Bluesky" } unless @user.has_valid_bluesky_token?

    begin
      collections = [
        'com.whtwnd.blog.entry',
        'app.bsky.feed.post',
        'app.bsky.actor.profile',
        'app.bsky.feed.like',
        'app.bsky.feed.repost',
        'app.bsky.graph.follow'
      ]

      results = []
      collections.each do |collection|
        result = fetch_records(collection, 5) # Just get a few from each
        if result[:success]
          results << {
            'name' => collection,
            'count' => result[:records].length
          }
        end
      end

      { success: true, collections: results }
    rescue => e
      Rails.logger.error "Error listing collections: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def fetch_records(collection, limit)
    url = "#{pds_endpoint}/xrpc/com.atproto.repo.listRecords"
    
    params = {
      repo: @user.uid,
      collection: collection,
      limit: limit
    }

    response = make_dpop_get_request(url, params)
    
    # Handle nonce requirement if needed
    if (response.status == 401 || response.status == 400) && 
       (response.body.include?('nonce') || response.body.include?('use_dpop_nonce'))
      Rails.logger.info "DPoP nonce required for record fetch, retrying"
      @dpop_nonce = response.headers['DPoP-Nonce']
      response = make_dpop_get_request(url, params)
    end

    Rails.logger.info "Record fetch response: #{response.status} - #{response.body[0..200]}..."

    if response.success?
      data = JSON.parse(response.body)
      { 
        success: true, 
        records: data['records'] || [], 
        cursor: data['cursor']
      }
    else
      error_data = JSON.parse(response.body) rescue {}
      { success: false, error: error_data['message'] || response.body }
    end
  end

  def fetch_single_record(repo, collection, rkey)
    url = "#{pds_endpoint}/xrpc/com.atproto.repo.getRecord"
    
    params = {
      repo: repo,
      collection: collection,
      rkey: rkey
    }

    response = make_dpop_get_request(url, params)
    
    # Handle nonce requirement if needed
    if (response.status == 401 || response.status == 400) && 
       (response.body.include?('nonce') || response.body.include?('use_dpop_nonce'))
      Rails.logger.info "DPoP nonce required for single record fetch, retrying"
      @dpop_nonce = response.headers['DPoP-Nonce']
      response = make_dpop_get_request(url, params)
    end

    if response.success?
      data = JSON.parse(response.body)
      { 
        success: true, 
        record: data['value'],
        uri: data['uri'],
        cid: data['cid']
      }
    else
      error_data = JSON.parse(response.body) rescue {}
      { success: false, error: error_data['message'] || response.body }
    end
  end

  def make_dpop_get_request(url, params = {})
    # Add query parameters to URL
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.any?
    
    # Generate DPoP token for GET request
    dpop_token = generate_dpop_token('GET', uri.to_s)
    
    Faraday.get(uri.to_s) do |req|
      req.headers['Authorization'] = "DPoP #{@user.access_token}"
      req.headers['DPoP'] = dpop_token
    end
  end

  def generate_dpop_token(method, url)
    # Create DPoP JWT token as required by Bluesky
    header = {
      typ: 'dpop+jwt',
      alg: 'ES256',
      jwk: @user.dpop_jwk
    }

    payload = {
      jti: SecureRandom.uuid,
      htm: method,
      htu: url,
      iat: Time.current.to_i,
      ath: access_token_hash
    }

    # Add nonce if we have one from previous requests
    payload[:nonce] = @dpop_nonce if @dpop_nonce

    # Sign with the user's DPoP private key
    JWT.encode(payload, @user.dpop_private_key, 'ES256', header)
  rescue => e
    Rails.logger.error "Error generating DPoP token: #{e.message}"
    raise e
  end

  def access_token_hash
    # Generate SHA-256 hash of the access token for DPoP "ath" field
    require 'digest'
    require 'base64'
    
    # Hash the access token and encode as base64url (without padding)
    hash = Digest::SHA256.digest(@user.access_token)
    Base64.urlsafe_encode64(hash, padding: false)
  end

  def pds_endpoint
    # Get the user's PDS endpoint from their DID document
    @pds_endpoint ||= resolve_pds_endpoint
  end

  def resolve_pds_endpoint
    # Use the DID resolution service to find the user's PDS
    did_doc_url = "https://plc.directory/#{@user.uid}"
    
    response = Faraday.get(did_doc_url)
    
    if response.success?
      did_doc = JSON.parse(response.body)
      
      # Find the PDS service endpoint
      services = did_doc['service'] || []
      pds_service = services.find { |service| service['id'] == '#atproto_pds' }
      
      if pds_service && pds_service['serviceEndpoint']
        Rails.logger.info "Resolved PDS endpoint: #{pds_service['serviceEndpoint']}"
        return pds_service['serviceEndpoint']
      end
    end
    
    # Fallback to default if resolution fails
    Rails.logger.warn "Could not resolve PDS endpoint for #{@user.uid}, using fallback"
    'https://bsky.social'
  rescue => e
    Rails.logger.error "Error resolving PDS endpoint: #{e.message}"
    'https://bsky.social'
  end
end
