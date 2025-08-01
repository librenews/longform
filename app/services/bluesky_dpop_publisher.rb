class BlueskyDpopPublisher
  require 'jwt'
  
  def initialize(user)
    @user = user
    @dpop_nonce = nil
  end

  def publish(title, content, post_url)
    return { success: false, error: "User not authenticated with Bluesky" } unless @user.has_valid_bluesky_token?

    begin
      # Format the post content
      post_text = format_content(title, content, post_url)
      
      # Create the post using PDS endpoint (com.atproto.repo.createRecord)
      result = create_post_record(post_text)
      
      if result[:success]
        Rails.logger.info "Successfully published to Bluesky with DPoP: #{result[:uri]}"
        { success: true, uri: result[:uri], cid: result[:cid] }
      else
        Rails.logger.error "Bluesky DPoP publish failed: #{result[:error]}"
        { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "Bluesky DPoP publish error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  private

  def create_post_record(text)
    # Use PDS endpoint for creating records (com.atproto.repo.createRecord)
    url = "#{pds_endpoint}/xrpc/com.atproto.repo.createRecord"
    
    # Try the request, handling nonce requirement
    response = make_dpop_request(url, text)
    
    # If we get a nonce requirement error, retry with the nonce
    if (response.status == 401 || response.status == 400) && 
       (response.body.include?('nonce') || response.body.include?('use_dpop_nonce'))
      Rails.logger.info "DPoP nonce required, retrying with nonce"
      @dpop_nonce = response.headers['DPoP-Nonce']
      Rails.logger.info "Extracted nonce: #{@dpop_nonce}"
      response = make_dpop_request(url, text)
    end

    Rails.logger.info "Bluesky DPoP API Response: #{response.status} - #{response.body}"

    if response.success?
      data = JSON.parse(response.body)
      { success: true, uri: data['uri'], cid: data['cid'] }
    else
      error_data = JSON.parse(response.body) rescue {}
      { success: false, error: error_data['message'] || response.body }
    end
  end

  def make_dpop_request(url, text)
    # Generate DPoP token for this request (will include nonce if we have one)
    dpop_token = generate_dpop_token('POST', url)
    
    Faraday.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "DPoP #{@user.access_token}"
      req.headers['DPoP'] = dpop_token
      req.body = {
        repo: @user.uid, # This is the user's DID
        collection: 'app.bsky.feed.post',
        record: {
          '$type': 'app.bsky.feed.post',
          text: text,
          createdAt: Time.current.iso8601
        }
      }.to_json
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

  def format_content(title, content, url)
    # Strip HTML tags from content and truncate
    plain_content = ActionView::Base.full_sanitizer.sanitize(content)
    
    # Build the post text
    post_parts = []
    post_parts << title if title.present?
    
    # Add content preview (truncated to fit within character limits)
    if plain_content.present?
      preview = plain_content.strip
      # Reserve space for title, URL, and formatting
      available_chars = 280 - (title&.length || 0) - (url&.length || 0) - 10 # buffer for formatting
      
      if preview.length > available_chars
        preview = preview[0...available_chars].gsub(/\s+\S*$/, '') + '...'
      end
      
      post_parts << preview
    end
    
    # Add the URL
    post_parts << url if url.present?
    
    post_parts.join("\n\n")
  end
end
