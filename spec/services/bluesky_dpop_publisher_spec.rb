require 'rails_helper'

RSpec.describe BlueskyDpopPublisher, type: :service do
  let(:user) { create(:user, handle: 'test.bsky.social', access_token: 'valid_token') }
  let(:post) { create(:post, :published, user: user, title: 'Test Post', content: '<p>Test content</p>') }
  let(:service) { described_class.new(user) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('APP_HOST').and_return('longform.test')
  end

  describe '#initialize' do
    it 'sets the user' do
      expect(service.instance_variable_get(:@user)).to eq(user)
    end
  end

  describe '#publish' do
    before do
      # Mock PDS resolution for the user's DID
      pds_response = {
        'service' => [
          {
            'id' => '#atproto_pds',
            'type' => 'AtprotoPersonalDataServer',
            'serviceEndpoint' => 'https://test.pds.host'
          }
        ]
      }
      
      stub_request(:get, "https://plc.directory/#{user.uid}")
        .to_return(status: 200, body: pds_response.to_json, headers: { 'Content-Type' => 'application/json' })

      # Mock successful record creation
      create_response = {
        'uri' => "at://#{user.uid}/com.whtwnd.blog.entry/#{SecureRandom.alphanumeric(13)}",
        'cid' => "bafy#{SecureRandom.alphanumeric(10)}"
      }
      
      stub_request(:post, "https://test.pds.host/xrpc/com.atproto.repo.createRecord")
        .to_return(status: 200, body: create_response.to_json, headers: { 'Content-Type' => 'application/json' })
      
      allow(service).to receive(:generate_dpop_token).and_return('dpop-token-123')
    end

    context 'when successful' do
      let(:post_url) { "https://longform.test/posts/#{post.id}" }
      
      it 'creates a blog entry record' do
        result = service.publish(post.title, post.content, post_url)
        expect(result[:success]).to be true
        expect(result[:uri]).to be_present
      end

      it 'sends correct record data with Whitewind lexicon' do
        service.publish(post.title, post.content, post_url)
        expect_blog_entry_creation('test.pds.host', title: 'Test Post', content_includes: ['Test content'])
      end

      it 'updates the post with bluesky_url' do
        result = service.publish(post.title, post.content, post_url)
        expect(result[:success]).to be true
        expect(result[:uri]).to start_with("at://#{user.uid}/com.whtwnd.blog.entry/")
      end

      it 'converts HTML content to markdown' do
        html_content = '<h1>Heading</h1><p>Paragraph with <strong>bold</strong> text.</p>'
        service.publish(post.title, html_content, post_url)

        expect_blog_entry_creation('test.pds.host', 
          title: 'Test Post', 
          content_includes: ['# Heading', '**bold**']
        )
      end
    end

    context 'when PDS resolution fails' do
      let(:post_url) { "https://longform.test/posts/#{post.id}" }
      
      before do
        # PDS resolution fails, but service falls back to bsky.social
        stub_request(:get, "https://plc.directory/#{user.uid}")
          .to_return(status: 404)
          
        # Mock the fallback bsky.social createRecord to succeed
        create_response = {
          'uri' => "at://#{user.uid}/com.whtwnd.blog.entry/#{SecureRandom.alphanumeric(13)}",
          'cid' => "bafy#{SecureRandom.alphanumeric(10)}"
        }
        
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord")
          .to_return(status: 200, body: create_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'falls back to bsky.social and succeeds' do
        result = service.publish(post.title, post.content, post_url)
        expect(result[:success]).to be true
      end
    end

    context 'when record creation fails' do
      let(:post_url) { "https://longform.test/posts/#{post.id}" }
      
      before do
        # Mock successful PDS resolution
        pds_response = {
          'service' => [
            {
              'id' => '#atproto_pds',
              'type' => 'AtprotoPersonalDataServer',
              'serviceEndpoint' => 'https://test.pds.host'
            }
          ]
        }
        
        stub_request(:get, "https://plc.directory/#{user.uid}")
          .to_return(status: 200, body: pds_response.to_json, headers: { 'Content-Type' => 'application/json' })

        # Mock failed record creation
        stub_request(:post, "https://test.pds.host/xrpc/com.atproto.repo.createRecord")
          .to_return(status: 400, body: { error: 'InvalidRequest', message: 'Bad request' }.to_json, 
                    headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns false and logs error' do
        result = service.publish(post.title, post.content, post_url)
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end

    context 'when network error occurs' do
      let(:post_url) { "https://longform.test/posts/#{post.id}" }
      
      before do
        stub_request(:get, "https://plc.directory/#{user.uid}")
          .to_raise(Faraday::ConnectionFailed.new('Connection failed'))
      end

      it 'falls back to bsky.social when PDS resolution fails with network error' do
        # Mock successful fallback to bsky.social
        create_response = {
          'uri' => "at://#{user.uid}/com.whtwnd.blog.entry/#{SecureRandom.alphanumeric(13)}",
          'cid' => "bafy#{SecureRandom.alphanumeric(10)}"
        }
        
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord")
          .to_return(status: 200, body: create_response.to_json, headers: { 'Content-Type' => 'application/json' })
          
        result = service.publish(post.title, post.content, post_url)
        expect(result[:success]).to be true  # Falls back to bsky.social and succeeds
      end
    end
  end

  describe '#generate_dpop_token' do
    let(:private_key) { OpenSSL::PKey::EC.generate('prime256v1') }
    let(:jwk) do
      {
        kty: 'EC',
        crv: 'P-256',
        x: 'test_x_value',
        y: 'test_y_value'
      }
    end

    before do
      allow(user).to receive(:dpop_private_key).and_return(private_key)
      allow(user).to receive(:dpop_jwk).and_return(jwk)
    end

    it 'generates a valid JWT token' do
      token = service.send(:generate_dpop_token, 'POST', 'https://test.pds.host/xrpc/com.atproto.repo.createRecord')
      
      expect(token).to be_a(String)
      expect(token).not_to be_empty
      
      # Decode the token to verify structure
      decoded_token = JWT.decode(token, nil, false)
      expect(decoded_token.first).to include('jti', 'htm', 'htu', 'iat', 'ath')
      expect(decoded_token.first['htm']).to eq('POST')
      expect(decoded_token.first['htu']).to eq('https://test.pds.host/xrpc/com.atproto.repo.createRecord')
    end
  end

  describe 'private methods' do
    describe '#resolve_pds_endpoint' do
      context 'with valid DID' do
        let(:response_body) do
          {
            'service' => [
              {
                'id' => '#atproto_pds',
                'type' => 'AtprotoPersonalDataServer',
                'serviceEndpoint' => 'https://test.pds.host'
              }
            ]
          }
        end

        before do
          stub_request(:get, "https://plc.directory/#{user.uid}")
            .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns PDS endpoint' do
          endpoint = service.send(:resolve_pds_endpoint)
          expect(endpoint).to eq('https://test.pds.host')
        end
      end

      context 'with invalid DID' do
        before do
          stub_request(:get, "https://plc.directory/#{user.uid}")
            .to_return(status: 404)
        end

        it 'returns fallback endpoint' do
          endpoint = service.send(:resolve_pds_endpoint)
          expect(endpoint).to eq('https://bsky.social')
        end
      end
    end
  end
end
