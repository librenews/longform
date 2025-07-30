require 'rails_helper'

RSpec.describe BlueskyPublisher, type: :service do
  let(:user) { create(:user, access_token: 'test_token') }
  let(:post) { create(:post, :draft, user: user, title: 'Test Post', content: 'This is a test post content.') }
  let(:service) { described_class.new(post) }

  describe '#initialize' do
    it 'sets the post and user' do
      expect(service.instance_variable_get(:@post)).to eq(post)
      expect(service.instance_variable_get(:@user)).to eq(user)
    end
  end

  describe '#publish', :vcr do
    let(:mock_response) do
      double('Response', 
        success?: true, 
        body: {
          'uri' => 'at://did:plc:test/app.bsky.feed.post/test123',
          'cid' => 'test_cid'
        }.to_json
      )
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(mock_response)
    end

    it 'creates a post record on Bluesky' do
      result = service.publish
      expect(result).to be_truthy
    end

    it 'updates the post with Bluesky URL' do
      service.publish
      post.reload
      expect(post.bluesky_url).to be_present
    end

    context 'when content is too long' do
      let(:long_content) { 'A' * 350 }
      let(:post) { create(:post, :draft, user: user, content: long_content) }

      it 'truncates content to fit character limit' do
        formatted_content = service.send(:format_content)
        expect(formatted_content.length).to be <= 300
        expect(formatted_content).to end_with('...')
      end
    end

    context 'when API request fails' do
      let(:error_response) do
        double('Response', success?: false, status: 400, body: 'Bad Request')
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(error_response)
      end

      it 'returns false' do
        result = service.publish
        expect(result).to be_falsey
      end

      it 'does not update the post' do
        original_url = post.bluesky_url
        service.publish
        expect(post.reload.bluesky_url).to eq(original_url)
      end
    end

    context 'when network error occurs' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed.new('Network error'))
      end

      it 'handles the error gracefully' do
        expect { service.publish }.not_to raise_error
      end

      it 'returns false' do
        result = service.publish
        expect(result).to be_falsey
      end
    end
  end

  describe '#format_content' do
    context 'with short content' do
      it 'returns title and content' do
        formatted = service.send(:format_content)
        expect(formatted).to include(post.title)
        expect(formatted).to include('This is a test post content.')
      end
    end

    context 'with long content' do
      let(:long_post) { create(:post, :long, user: user, title: 'Long Post') }
      let(:service) { described_class.new(long_post) }

      it 'truncates content and adds ellipsis' do
        formatted = service.send(:format_content)
        expect(formatted.length).to be <= 300
        expect(formatted).to end_with('...')
      end
    end

    context 'with content containing links' do
      let(:content_with_link) { 'Check out this link: https://example.com and this one too!' }
      let(:post) { create(:post, user: user, content: content_with_link) }

      it 'preserves links in the content' do
        formatted = service.send(:format_content)
        expect(formatted).to include('https://example.com')
      end
    end
  end

  describe '#extract_facets' do
    let(:content) { 'Visit https://example.com and https://test.org for more info!' }
    
    it 'extracts links as facets' do
      facets = service.send(:extract_facets, content)
      expect(facets).to be_an(Array)
      expect(facets.length).to eq(2)
      
      first_facet = facets.first
      expect(first_facet[:index][:byteStart]).to be_a(Integer)
      expect(first_facet[:index][:byteEnd]).to be_a(Integer)
      expect(first_facet[:features]).to be_an(Array)
      expect(first_facet[:features].first[:$type]).to eq('app.bsky.richtext.facet#link')
      expect(first_facet[:features].first[:uri]).to eq('https://example.com')
    end

    context 'with no links' do
      let(:content) { 'This is a post without any links.' }
      
      it 'returns empty array' do
        facets = service.send(:extract_facets, content)
        expect(facets).to eq([])
      end
    end

    context 'with malformed URLs' do
      let(:content) { 'This has a malformed url: htp://bad-url' }
      
      it 'ignores malformed URLs' do
        facets = service.send(:extract_facets, content)
        expect(facets).to eq([])
      end
    end
  end

  describe '#build_client' do
    it 'creates a Faraday connection with correct base URL' do
      client = service.send(:build_client)
      expect(client).to be_a(Faraday::Connection)
      expect(client.url_prefix.to_s).to eq('https://bsky.social/')
    end

    it 'sets up JSON middleware' do
      client = service.send(:build_client)
      expect(client.builder.handlers).to include(Faraday::Request::Json)
      expect(client.builder.handlers).to include(Faraday::Response::Json)
    end

    it 'includes authorization header' do
      client = service.send(:build_client)
      # We can't directly test the headers without making a request,
      # but we can verify the client is configured
      expect(client.headers['Authorization']).to eq('Bearer test_token')
    end
  end

  describe 'integration test' do
    let(:real_response_body) do
      {
        'uri' => 'at://did:plc:test123/app.bsky.feed.post/abc123',
        'cid' => 'bafytest123'
      }
    end

    before do
      # Mock the entire HTTP call chain
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.createRecord')
        .with(
          body: hash_including(
            collection: 'app.bsky.feed.post',
            record: hash_including(
              '$type' => 'app.bsky.feed.post',
              text: include(post.title),
              createdAt: be_a(String)
            )
          ),
          headers: {
            'Authorization' => 'Bearer test_token',
            'Content-Type' => 'application/json'
          }
        )
        .to_return(
          status: 200,
          body: real_response_body.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'successfully publishes a post and updates the model' do
      result = service.publish
      
      expect(result).to be_truthy
      post.reload
      expect(post.bluesky_url).to include('abc123')
    end
  end
end
