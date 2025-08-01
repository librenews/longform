class BlueskyAppPasswordPublisher
  include HTTParty
  base_uri 'https://bsky.social'

  def initialize(handle, app_password)
    @handle = handle
    @app_password = app_password
    @access_jwt = nil
    @refresh_jwt = nil
  end

  def publish(title, content, url)
    return { success: false, error: "Missing credentials" } unless @handle && @app_password

    begin
      # Step 1: Create session (authenticate)
      auth_result = authenticate
      return auth_result unless auth_result[:success]

      # Step 2: Create the post record
      post_result = create_post(title, content, url)
      return post_result
    rescue => e
      Rails.logger.error "Bluesky App Password publish error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def authenticate
    response = self.class.post('/xrpc/com.atproto.server.createSession', {
      body: {
        identifier: @handle,
        password: @app_password
      }.to_json,
      headers: {
        'Content-Type' => 'application/json'
      }
    })

    if response.success?
      data = response.parsed_response
      @access_jwt = data['accessJwt']
      @refresh_jwt = data['refreshJwt']
      @did = data['did']
      
      Rails.logger.info "Bluesky session created successfully for #{@handle}"
      { success: true }
    else
      error_msg = response.parsed_response&.dig('message') || 'Authentication failed'
      Rails.logger.error "Bluesky authentication failed: #{error_msg}"
      { success: false, error: error_msg }
    end
  end

  def create_post(title, content, url)
    # Format the post content
    post_text = format_post_content(title, content, url)
    
    # Create the post record
    response = self.class.post('/xrpc/com.atproto.repo.createRecord', {
      body: {
        repo: @did,
        collection: 'app.bsky.feed.post',
        record: {
          text: post_text,
          createdAt: Time.current.iso8601,
          '$type': 'app.bsky.feed.post'
        }
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@access_jwt}"
      }
    })

    if response.success?
      data = response.parsed_response
      Rails.logger.info "Bluesky post created successfully: #{data['uri']}"
      { success: true, uri: data['uri'], cid: data['cid'] }
    else
      error_msg = response.parsed_response&.dig('message') || 'Post creation failed'
      Rails.logger.error "Bluesky post creation failed: #{error_msg}"
      { success: false, error: error_msg }
    end
  end

  def format_post_content(title, content, url)
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
