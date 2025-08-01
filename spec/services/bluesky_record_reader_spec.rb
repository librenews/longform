require 'rails_helper'

RSpec.describe BlueskyRecordReader, type: :service do
  # Global WebMock stubs to catch all AT Protocol requests
  before(:all) do
    # Catch all plc.directory requests
    stub_request(:any, /plc\.directory/)
      .to_return(status: 200, body: {
        'service' => [
          {
            'id' => '#atproto_pds',
            'type' => 'AtprotoPersonalDataServer',
            'serviceEndpoint' => 'https://test.pds.host'
          }
        ]
      }.to_json, headers: { 'Content-Type' => 'application/json' })
    
    # Catch all AT Protocol API requests
    stub_request(:any, /\.host\/xrpc\//)
      .to_return(status: 200, body: { records: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  let(:user) { create(:user, :fresh_tokens) }
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

  describe '#list_all_collections' do
    before do
      # Mock PDS resolution for any DID using a very broad stub
      stub_request(:get, /plc\.directory/)
        .to_return(status: 200, body: {
          'service' => [
            {
              'id' => '#atproto_pds',
              'type' => 'AtprotoPersonalDataServer',
              'serviceEndpoint' => 'https://test.pds.host'
            }
          ]
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      # Mock records list with broad patterns
      [
        'com.whtwnd.blog.entry',
        'app.bsky.feed.post',
        'app.bsky.actor.profile',
        'app.bsky.feed.like',
        'app.bsky.feed.repost',
        'app.bsky.graph.follow'
      ].each do |collection|
        stub_request(:get, /test\.pds\.host.*listRecords/)
          .with(query: hash_including(
            'collection' => collection, 
            'limit' => 5
          ))
          .to_return(status: 200, body: { records: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
      end
    end

    it 'returns list of collections' do
      result = service.list_all_collections
      expect(result[:success]).to be true
      expect(result[:collections]).to be_an(Array)
    end

    context 'when request fails' do
      before do
        # Mock PDS resolution to return bsky.social to trigger error flow
        stub_request(:get, /plc\.directory/)
          .to_return(status: 200, body: { 
            'service' => [
              {
                'id' => '#atproto_pds',
                'type' => 'AtprotoPersonalDataServer',
                'serviceEndpoint' => 'https://bsky.social'
              }
            ]
          }.to_json, headers: { 'Content-Type' => 'application/json' })
        
        # Mock listRecords request to fail
        stub_request(:get, /bsky\.social.*listRecords/)
          .to_return(status: 400, body: { error: 'BadRequest', message: 'Collection not found' }.to_json)
      end

      it 'returns error response' do
        result = service.list_all_collections
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#list_records' do
    let(:pds_response) do
      {
        'did' => 'did:plc:test123',
        'didDoc' => {
          'service' => [
            {
              'id' => '#atproto_pds',
              'type' => 'AtprotoPersonalDataServer',
              'serviceEndpoint' => 'https://test.pds.host'
            }
          ]
        }
      }
    end

    let(:records_response) do
      {
        'records' => [
          {
            'uri' => 'at://did:plc:test123/com.whtwnd.blog.entry/record1',
            'cid' => 'bafytest1',
            'value' => {
              '$type' => 'com.whtwnd.blog.entry',
              'title' => 'First Blog Post',
              'content' => 'Content of first post',
              'createdAt' => '2024-01-01T10:00:00Z'
            }
          },
          {
            'uri' => 'at://did:plc:test123/com.whtwnd.blog.entry/record2',
            'cid' => 'bafytest2',
            'value' => {
              '$type' => 'com.whtwnd.blog.entry',
              'title' => 'Second Blog Post',
              'content' => 'Content of second post',
              'createdAt' => '2024-01-02T10:00:00Z'
            }
          }
        ],
        'cursor' => 'next_cursor_123'
      }
    end

    before do
      # Mock PDS resolution for user's DID
      pds_response = {
        'service' => [
          {
            'id' => '#atproto_pds',
            'type' => 'AtprotoPersonalDataServer',
            'serviceEndpoint' => 'https://test.pds.host'
          }
        ]
      }
      
      # Mock PDS resolution for any DID
      stub_request(:get, /plc\.directory/)
        .to_return(status: 200, body: pds_response.to_json, headers: { 'Content-Type' => 'application/json' })

      # Mock records list with more flexible matching
      stub_request(:get, /test\.pds\.host.*listRecords/)
        .with(query: hash_including(
          'collection' => 'com.whtwnd.blog.entry'
        ))
        .to_return(status: 200, body: records_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns records and cursor' do
      result = service.list_records('com.whtwnd.blog.entry')

      expect(result[:success]).to be true
      expect(result[:records].size).to eq(2)
      expect(result[:records].first['uri']).to eq('at://did:plc:test123/com.whtwnd.blog.entry/record1')
      expect(result[:records].first['value']['title']).to eq('First Blog Post')
      expect(result[:cursor]).to eq('next_cursor_123')
    end

    it 'sends correct request parameters' do
      service.list_records('com.whtwnd.blog.entry', 10)

      expect(WebMock).to have_requested(:get, "https://test.pds.host/xrpc/com.atproto.repo.listRecords")
        .with(
          query: { 
            repo: user.uid, 
            collection: 'com.whtwnd.blog.entry', 
            limit: 10
          },
          headers: {
            'Authorization' => "DPoP #{user.access_token}",
            'DPoP' => /^ey.*/ # JWT token pattern
          }
        )
    end

    context 'when request fails' do
      before do
        # Mock PDS resolution for any DID
        stub_request(:get, /plc\.directory/)
          .to_return(status: 200, body: {
            'service' => [
              {
                'id' => '#atproto_pds',
                'type' => 'AtprotoPersonalDataServer',
                'serviceEndpoint' => 'https://test.pds.host'
              }
            ]
          }.to_json, headers: { 'Content-Type' => 'application/json' })
        
        # Mock listRecords request to fail
        stub_request(:get, /test\.pds\.host.*listRecords/)
          .with(query: hash_including('collection' => 'invalid.collection'))
          .to_return(status: 400, body: { error: 'CollectionNotFound' }.to_json)
      end

      it 'returns empty results' do
        result = service.list_records('invalid.collection')
        
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch records/)
        service.list_records('invalid.collection')
      end
    end
  end

  describe '#get_record' do
    let(:pds_response) do
      {
        'did' => 'did:plc:test123',
        'didDoc' => {
          'service' => [
            {
              'id' => '#atproto_pds',
              'type' => 'AtprotoPersonalDataServer',
              'serviceEndpoint' => 'https://test.pds.host'
            }
          ]
        }
      }
    end

    let(:record_response) do
      {
        'uri' => 'at://did:plc:test123/com.whtwnd.blog.entry/record1',
        'cid' => 'bafytest1',
        'value' => {
          '$type' => 'com.whtwnd.blog.entry',
          'title' => 'Test Blog Post',
          'content' => 'This is the content of the blog post',
          'createdAt' => '2024-01-01T10:00:00Z',
          'visibility' => 'public'
        }
      }
    end

    before do
      # Mock PDS resolution for user's DID
      pds_response = {
        'service' => [
          {
            'id' => '#atproto_pds',
            'type' => 'AtprotoPersonalDataServer',
            'serviceEndpoint' => 'https://test.pds.host'
          }
        ]
      }
      
      # Mock PDS resolution for any DID
      stub_request(:get, /plc\.directory/)
        .to_return(status: 200, body: pds_response.to_json, headers: { 'Content-Type' => 'application/json' })

      # Mock record get with flexible matching
      stub_request(:get, /test\.pds\.host.*getRecord/)
        .with(query: hash_including(
          'collection' => 'com.whtwnd.blog.entry', 
          'rkey' => 'record1' 
        ))
        .to_return(status: 200, body: record_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns the record' do
      at_uri = "at://#{user.uid}/com.whtwnd.blog.entry/record1"
      result = service.get_record(at_uri)

      expect(result[:success]).to be true
      expect(result[:record]['value']['title']).to eq('Test Blog Post')
      expect(result[:record]['value']['content']).to eq('This is the content of the blog post')
    end

    it 'sends correct request' do
      at_uri = "at://#{user.uid}/com.whtwnd.blog.entry/record1"
      service.get_record(at_uri)

      expect(WebMock).to have_requested(:get, "https://test.pds.host/xrpc/com.atproto.repo.getRecord")
        .with(query: hash_including(
          repo: user.uid, 
          collection: 'com.whtwnd.blog.entry', 
          rkey: 'record1' 
        ))
    end

    context 'when record not found' do
      before do
        # Mock PDS resolution for any DID
        stub_request(:get, /plc\.directory/)
          .to_return(status: 200, body: {
            'service' => [
              {
                'id' => '#atproto_pds',
                'type' => 'AtprotoPersonalDataServer',
                'serviceEndpoint' => 'https://test.pds.host'
              }
            ]
          }.to_json, headers: { 'Content-Type' => 'application/json' })
        
        # Mock getRecord request to fail
        stub_request(:get, /test\.pds\.host.*getRecord/)
          .with(query: hash_including('rkey' => 'nonexistent'))
          .to_return(status: 404, body: { error: 'RecordNotFound' }.to_json)
      end

      it 'returns error result' do
        at_uri = "at://#{user.uid}/com.whtwnd.blog.entry/nonexistent"
        result = service.get_record(at_uri)
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end

      it 'logs the error' do
        at_uri = "at://#{user.uid}/com.whtwnd.blog.entry/nonexistent"
        expect(Rails.logger).to receive(:error).with(/Failed to fetch record/)
        service.get_record(at_uri)
      end
    end
  end

  describe 'shared DPoP functionality' do
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
        token = service.send(:generate_dpop_token, 'GET', 'https://test.pds.host/xrpc/com.atproto.repo.listRecords')
        
        expect(token).to be_a(String)
        expect(token).not_to be_empty
        
        # Decode the token to verify structure
        decoded_token = JWT.decode(token, nil, false)
        expect(decoded_token.first).to include('jti', 'htm', 'htu', 'iat', 'ath')
        expect(decoded_token.first['htm']).to eq('GET')
        expect(decoded_token.first['htu']).to eq('https://test.pds.host/xrpc/com.atproto.repo.listRecords')
      end
    end

    describe 'error handling' do
      context 'when PDS resolution fails' do
        before do
          stub_request(:get, /plc\.directory/)
            .to_return(status: 404)
        end

        it 'handles resolution errors gracefully' do
          result = service.list_all_collections
          expect(result[:success]).to be false
          expect(result[:error]).to be_present
        end
      end

      context 'when network errors occur' do
        before do
          stub_request(:get, /plc\.directory/)
            .to_raise(Faraday::ConnectionFailed.new('Connection failed'))
        end

        it 'handles network errors gracefully' do
          result = service.list_all_collections
          expect(result[:success]).to be false
          expect(result[:error]).to be_present
        end
      end
    end
  end
end
