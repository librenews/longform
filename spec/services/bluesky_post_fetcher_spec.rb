require 'rails_helper'

RSpec.describe BlueskyPostFetcher do
  let(:user) { create(:user, :with_valid_tokens) }
  let(:fetcher) { described_class.new(user) }

  before do
    # Enable WebMock request debugging
    WebMock.after_request do |request_signature, response|
      puts "WebMock intercepted request: #{request_signature.method.upcase} #{request_signature.uri}"
      puts "Headers: #{request_signature.headers}"
      puts "Query: #{CGI.parse(URI.parse(request_signature.uri.to_s).query || '')}"
      puts "---"
    end
  end

  after do
    WebMock.reset_callbacks
  end

  before do
    # Stub PDS endpoint resolution
    stub_request(:get, /plc\.directory/)
      .to_return(
        status: 200,
        body: {
          "service" => [
            {
              "id" => "#atproto_pds",
              "type" => "AtprotoPersonalDataServer",
              "serviceEndpoint" => "https://morel.us-east.host.bsky.network"
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#fetch_latest_posts' do
    around do |example|
      VCR.turned_off do
        WebMock.allow_net_connect!
        example.run
        WebMock.disable_net_connect!
      end
    end
    context 'when user has valid tokens' do
      before do
        # Enable all WebMock stubbing
        WebMock.enable!
        
        # Stub the PDS resolution call
        stub_request(:get, "https://plc.directory/#{user.uid}")
          .to_return(
            status: 200,
            body: {
              "service" => [
                {
                  "id" => "#atproto_pds",
                  "serviceEndpoint" => "https://morel.us-east.host.bsky.network"
                }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Stub the actual blog posts API call - even more flexible
        stub_request(:get, /morel\.us-east\.host\.bsky\.network/)
          .to_return(
            status: 200,
            body: {
              "records" => [
                {
                  "uri" => "at://did:plc:test/com.whtwnd.blog.entry/123",
                  "cid" => "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                  "value" => {
                    "title" => "Test Blog Post",
                    "content" => "This is a test blog post with some content that is long enough to test word counting and preview generation functionality.",
                    "createdAt" => "2025-08-04T12:00:00Z",
                    "visibility" => "public"
                  }
                },
                {
                  "uri" => "at://did:plc:test/com.whtwnd.blog.entry/124",
                  "cid" => "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                  "value" => {
                    "title" => "Private Post",
                    "content" => "This is a private post",
                    "createdAt" => "2025-08-04T11:00:00Z",
                    "visibility" => "private"
                  }
                }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns an array of blog posts' do
        # Debug user state
        puts "User provider: #{user.provider}"
        puts "User access_token: #{user.access_token.present?}"
        puts "User token_expired?: #{user.token_expired?}"
        puts "User has_valid_bluesky_token?: #{user.has_valid_bluesky_token?}"
        puts "User pds_endpoint: #{user.pds_endpoint}"
        
        posts = fetcher.fetch_latest_posts
        
        puts "Posts returned: #{posts.length}"
        
        expect(posts).to be_an(Array)
        expect(posts.length).to eq(1) # Only public posts
        
        post = posts.first
        expect(post[:title]).to eq("Test Blog Post")
        expect(post[:uri]).to start_with("at://")
        expect(post[:visibility]).to eq("public")
        expect(post[:word_count]).to be > 0
        expect(post[:preview]).to be_present
      end

      it 'filters out private posts' do
        posts = fetcher.fetch_latest_posts
        
        # Should only include public posts
        expect(posts.all? { |p| p[:visibility] == 'public' }).to be true
      end

      it 'includes word count and preview' do
        posts = fetcher.fetch_latest_posts
        post = posts.first
        
        expect(post[:word_count]).to eq(21) # Word count of the test content
        expect(post[:preview]).to include("This is a test blog post")
      end
    end

    context 'when user has no valid tokens' do
      let(:user) { create(:user, access_token: nil) }

      it 'returns empty array' do
        posts = fetcher.fetch_latest_posts
        expect(posts).to eq([])
      end
    end
  end

  describe '#fetch_post_by_uri' do
    let(:test_uri) { "at://did:plc:test/com.whtwnd.blog.entry/123" }

    before do
      # Disable VCR for these tests since we're using WebMock
      VCR.turn_off!
    end

    after do
      VCR.turn_on!
    end

    context 'when post exists' do
      before do
        # Stub the PDS resolution call
        stub_request(:get, "https://plc.directory/#{user.uid}")
          .to_return(
            status: 200,
            body: {
              "service" => [
                {
                  "id" => "#atproto_pds",
                  "serviceEndpoint" => "https://morel.us-east.host.bsky.network"
                }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Stub the getRecord API call - broader pattern
        stub_request(:get, /morel\.us-east\.host\.bsky\.network.*getRecord/)
          .to_return(
            status: 200,
            body: {
              "uri" => test_uri,
              "cid" => "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
              "value" => {
                "title" => "Single Blog Post",
                "content" => "This is a single blog post",
                "createdAt" => "2025-08-04T12:00:00Z",
                "visibility" => "public"
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the specific post' do
        post = fetcher.fetch_post_by_uri(test_uri)
        
        expect(post).to be_a(Hash)
        expect(post[:uri]).to eq(test_uri)
        expect(post[:title]).to eq("Single Blog Post")
        expect(post[:word_count]).to eq(6)
      end
    end

    context 'when invalid URI provided' do
      it 'returns nil for invalid AT URI' do
        post = fetcher.fetch_post_by_uri("invalid-uri")
        expect(post).to be_nil
      end
    end
  end
end
