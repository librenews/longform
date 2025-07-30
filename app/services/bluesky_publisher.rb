class BlueskyPublisher
  include HTTParty
  base_uri 'https://bsky.social/xrpc'
  
  def initialize(post)
    @post = post
    @user = post.user
    @connection = Faraday.new(url: 'https://bsky.social') do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end
  
  def publish
    return { success: false, error: 'Invalid token' } unless @user.valid_token?
    
    begin
      # Format content for AT Protocol
      formatted_content = format_content
      
      # Create the post record
      response = @connection.post('/xrpc/com.atproto.repo.createRecord') do |req|
        req.headers['Authorization'] = "Bearer #{@user.access_token}"
        req.body = {
          repo: @user.uid, # DID is stored in uid field
          collection: 'app.bsky.feed.post',
          record: {
            '$type' => 'app.bsky.feed.post',
            text: formatted_content[:text],
            facets: formatted_content[:facets],
            createdAt: Time.current.iso8601
          }
        }
      end
      
      if response.success?
        {
          success: true,
          uri: response.body['uri'],
          cid: response.body['cid'],
          metadata: response.body
        }
      else
        {
          success: false,
          error: response.body['message'] || 'Unknown error'
        }
      end
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  private
  
  def format_content
    # Convert HTML content to plain text with basic formatting
    plain_text = @post.content.to_plain_text
    
    # For now, we'll use a simple approach
    # In a full implementation, you'd parse HTML and extract:
    # - Links with proper facets
    # - Mentions with proper facets
    # - Hashtags with proper facets
    
    # Truncate to Bluesky's character limit (300 chars)
    text = if plain_text.length > 280
      # Add title if truncating
      title_prefix = @post.title.present? ? "#{@post.title}\n\n" : ""
      available_length = 280 - title_prefix.length - 3 # -3 for "..."
      
      if available_length > 50
        "#{title_prefix}#{plain_text[0...available_length]}..."
      else
        plain_text[0...280]
      end
    else
      title_prefix = @post.title.present? ? "#{@post.title}\n\n" : ""
      "#{title_prefix}#{plain_text}"
    end
    
    {
      text: text,
      facets: extract_facets(text)
    }
  end
  
  def extract_facets(text)
    facets = []
    
    # Extract URLs (simple regex for now)
    url_regex = /https?:\/\/[^\s]+/
    text.scan(url_regex).each do |url|
      start_pos = text.index(url)
      if start_pos
        facets << {
          index: {
            byteStart: start_pos,
            byteEnd: start_pos + url.length
          },
          features: [{
            '$type' => 'app.bsky.richtext.facet#link',
            uri: url
          }]
        }
      end
    end
    
    facets
  end
end
