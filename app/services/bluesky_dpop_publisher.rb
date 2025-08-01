class BlueskyDpopPublisher
  require 'jwt'
  
  def initialize(user)
    @user = user
    @dpop_nonce = nil
  end

  def publish(title, content, post_url)
    return { success: false, error: "User not authenticated with Bluesky" } unless @user.has_valid_bluesky_token?

    begin
      # Create the blog entry using Whitewind lexicon for longform content
      result = create_blog_entry(title, content, post_url)
      
      if result[:success]
        Rails.logger.info "Successfully published blog entry to Bluesky with DPoP: #{result[:uri]}"
        { success: true, uri: result[:uri], cid: result[:cid] }
      else
        Rails.logger.error "Bluesky DPoP blog entry publish failed: #{result[:error]}"
        { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "Bluesky DPoP blog entry publish error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  def delete_record(at_uri)
    return false unless @user.has_valid_bluesky_token?
    return false if at_uri.blank?

    begin
      # Parse AT URI to extract repo and rkey
      # Format: at://did:plc:xxx/collection/rkey
      uri_parts = at_uri.match(%r{^at://([^/]+)/([^/]+)/([^/]+)$})
      unless uri_parts
        Rails.logger.error "Invalid AT URI format: #{at_uri}"
        return false
      end

      repo = uri_parts[1]
      collection = uri_parts[2]
      rkey = uri_parts[3]

      result = delete_at_record(repo, collection, rkey)
      
      if result[:success]
        Rails.logger.info "Successfully deleted record from Bluesky: #{at_uri}"
        true
      else
        Rails.logger.error "Failed to delete AT Protocol record: #{result[:error]}"
        false
      end
    rescue => e
      Rails.logger.error "Failed to delete AT Protocol record: #{e.message}"
      false
    end
  end

  private

  def create_blog_entry(title, content, post_url)
    # Use PDS endpoint for creating records with Whitewind blog lexicon
    url = "#{pds_endpoint}/xrpc/com.atproto.repo.createRecord"
    
    # Try the request, handling nonce requirement
    response = make_dpop_request(url, title, content, post_url)
    
    # If we get a nonce requirement error, retry with the nonce
    if (response.status == 401 || response.status == 400) && 
       (response.body.include?('nonce') || response.body.include?('use_dpop_nonce'))
      Rails.logger.info "DPoP nonce required, retrying with nonce"
      @dpop_nonce = response.headers['DPoP-Nonce']
      Rails.logger.info "Extracted nonce: #{@dpop_nonce}"
      response = make_dpop_request(url, title, content, post_url)
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

  def delete_at_record(repo, collection, rkey)
    # Use PDS endpoint for deleting records
    url = "#{pds_endpoint}/xrpc/com.atproto.repo.deleteRecord"
    
    # Try the request, handling nonce requirement
    response = make_dpop_delete_request(url, repo, collection, rkey)
    
    # If we get a nonce requirement error, retry with the nonce
    if (response.status == 401 || response.status == 400) && 
       (response.body.include?('nonce') || response.body.include?('use_dpop_nonce'))
      Rails.logger.info "DPoP nonce required for deletion, retrying with nonce"
      @dpop_nonce = response.headers['DPoP-Nonce']
      Rails.logger.info "Extracted nonce: #{@dpop_nonce}"
      response = make_dpop_delete_request(url, repo, collection, rkey)
    end

    Rails.logger.info "Bluesky DPoP Delete Response: #{response.status} - #{response.body}"

    if response.success?
      { success: true }
    else
      error_data = JSON.parse(response.body) rescue {}
      { success: false, error: error_data['message'] || response.body }
    end
  end

  def make_dpop_request(url, title, content, post_url)
    # Generate DPoP token for this request (will include nonce if we have one)
    dpop_token = generate_dpop_token('POST', url)
    
    # Prepare content - convert HTML to markdown for better blog compatibility
    markdown_content = convert_to_markdown(content)
    
    # Build the blog entry record according to Whitewind lexicon
    blog_record = {
      '$type': 'com.whtwnd.blog.entry',
      content: markdown_content,
      createdAt: Time.current.iso8601,
      visibility: 'public'
    }
    
    # Add title if present
    blog_record[:title] = title if title.present?
    
    # Add URL as a reference/link in the content if provided
    if post_url.present?
      blog_record[:content] += "\n\n---\n*Originally published at: #{post_url}*"
    end
    
    Faraday.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "DPoP #{@user.access_token}"
      req.headers['DPoP'] = dpop_token
      req.body = {
        repo: @user.uid, # This is the user's DID
        collection: 'com.whtwnd.blog.entry', # Use Whitewind blog collection
        record: blog_record
      }.to_json
    end
  end

  def make_dpop_delete_request(url, repo, collection, rkey)
    # Generate DPoP token for this delete request
    dpop_token = generate_dpop_token('POST', url)
    
    Faraday.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "DPoP #{@user.access_token}"
      req.headers['DPoP'] = dpop_token
      req.body = {
        repo: repo,
        collection: collection,
        rkey: rkey
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

  def convert_to_markdown(html_content)
    # Use reverse_markdown for professional HTML to Markdown conversion
    require 'reverse_markdown'
    
    # Convert HTML to markdown with simple options
    ReverseMarkdown.convert(html_content, unknown_tags: :bypass, github_flavored: true)
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
