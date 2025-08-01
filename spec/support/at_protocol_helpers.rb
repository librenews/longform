require 'webmock/rspec'

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    WebMock.reset!
  end
end

# AT Protocol test helpers
module ATProtocolTestHelpers
  def stub_at_protocol_success(handle: 'test.bsky.social', did: 'did:plc:test123', pds_host: 'test.pds.host')
    # Mock PDS resolution
    pds_response = {
      'did' => did,
      'didDoc' => {
        'service' => [
          {
            'id' => '#atproto_pds',
            'type' => 'AtprotoPersonalDataServer',
            'serviceEndpoint' => "https://#{pds_host}"
          }
        ]
      }
    }
    
    stub_request(:get, "https://plc.directory/did:web:#{handle}")
      .to_return(status: 200, body: pds_response.to_json, headers: { 'Content-Type' => 'application/json' })

    # Mock DPoP nonce request
    stub_request(:post, "https://#{pds_host}/xrpc/com.atproto.server.getSession")
      .to_return(status: 401, headers: { 'dpop-nonce' => 'test-nonce-123' })

    # Mock successful record creation
    create_response = {
      'uri' => "at://#{did}/com.whtwnd.blog.entry/#{SecureRandom.alphanumeric(13)}",
      'cid' => "bafy#{SecureRandom.alphanumeric(10)}"
    }
    
    stub_request(:post, "https://#{pds_host}/xrpc/com.atproto.repo.createRecord")
      .to_return(status: 200, body: create_response.to_json, headers: { 'Content-Type' => 'application/json' })

    pds_host
  end

  def stub_at_protocol_failure(handle: 'test.bsky.social', error_status: 400, error_body: { error: 'InvalidRequest' })
    pds_host = stub_at_protocol_success(handle: handle)
    
    # Override the create record request to return an error
    stub_request(:post, "https://#{pds_host}/xrpc/com.atproto.repo.createRecord")
      .to_return(status: error_status, body: error_body.to_json, headers: { 'Content-Type' => 'application/json' })

    pds_host
  end

  def stub_records_browser(handle: 'test.bsky.social', did: 'did:plc:test123', pds_host: 'test.pds.host')
    # First stub the basic AT Protocol setup
    stub_at_protocol_success(handle: handle, did: did, pds_host: pds_host)

    # Mock collections list
    collections_response = {
      'collections' => [
        'app.bsky.feed.post',
        'com.whtwnd.blog.entry',
        'app.bsky.actor.profile'
      ]
    }
    
    stub_request(:get, "https://#{pds_host}/xrpc/com.atproto.repo.describeRepo")
      .with(query: { repo: did })
      .to_return(status: 200, body: collections_response.to_json, headers: { 'Content-Type' => 'application/json' })

    # Mock records list
    records_response = {
      'records' => [
        {
          'uri' => "at://#{did}/com.whtwnd.blog.entry/record1",
          'cid' => 'bafytest1',
          'value' => {
            '$type' => 'com.whtwnd.blog.entry',
            'title' => 'Test Blog Post',
            'content' => 'Content of the blog post',
            'createdAt' => '2024-01-01T10:00:00Z'
          }
        },
        {
          'uri' => "at://#{did}/com.whtwnd.blog.entry/record2",
          'cid' => 'bafytest2',
          'value' => {
            '$type' => 'com.whtwnd.blog.entry',
            'title' => 'Another Blog Post',
            'content' => 'More content here',
            'createdAt' => '2024-01-02T10:00:00Z'
          }
        }
      ],
      'cursor' => 'next_cursor_123'
    }
    
    stub_request(:get, "https://#{pds_host}/xrpc/com.atproto.repo.listRecords")
      .to_return(status: 200, body: records_response.to_json, headers: { 'Content-Type' => 'application/json' })

    # Mock individual record get
    record_response = {
      'uri' => "at://#{did}/com.whtwnd.blog.entry/record1",
      'cid' => 'bafytest1',
      'value' => {
        '$type' => 'com.whtwnd.blog.entry',
        'title' => 'Test Blog Post',
        'content' => 'Content of the blog post',
        'createdAt' => '2024-01-01T10:00:00Z',
        'visibility' => 'public'
      }
    }
    
    stub_request(:get, "https://#{pds_host}/xrpc/com.atproto.repo.getRecord")
      .to_return(status: 200, body: record_response.to_json, headers: { 'Content-Type' => 'application/json' })

    pds_host
  end

  def expect_blog_entry_creation(pds_host, title:, content_includes: [])
    expect(WebMock).to have_requested(:post, "https://#{pds_host}/xrpc/com.atproto.repo.createRecord")
      .with { |req|
        body = JSON.parse(req.body)
        expect(body['collection']).to eq('com.whtwnd.blog.entry')
        expect(body['record']['$type']).to eq('com.whtwnd.blog.entry')
        expect(body['record']['title']).to eq(title)
        
        content_includes.each do |text|
          expect(body['record']['content']).to include(text)
        end
        
        true
      }
  end
end

RSpec.configure do |config|
  config.include ATProtocolTestHelpers
end
