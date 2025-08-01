class BlueskySessionManager
  def initialize(identifier, password)
    @identifier = identifier # handle or email
    @password = password # app password from Bluesky settings
    @connection = Faraday.new(url: 'https://bsky.social') do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end
  
  def create_session
    response = @connection.post('/xrpc/com.atproto.server.createSession') do |req|
      req.body = {
        identifier: @identifier,
        password: @password
      }
    end
    
    if response.success?
      {
        success: true,
        access_jwt: response.body['accessJwt'],
        refresh_jwt: response.body['refreshJwt'],
        did: response.body['did'],
        handle: response.body['handle']
      }
    else
      {
        success: false,
        error: response.body['message'] || 'Failed to create session'
      }
    end
  rescue => e
    {
      success: false,
      error: e.message
    }
  end
  
  def self.test_connection
    # Simple test to verify we can reach the AT Protocol API
    connection = Faraday.new(url: 'https://bsky.social') do |conn|
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
    
    response = connection.get('/xrpc/com.atproto.server.describeServer')
    {
      success: response.success?,
      server_info: response.body
    }
  rescue => e
    {
      success: false,
      error: e.message
    }
  end
end
