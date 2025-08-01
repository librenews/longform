require 'rails_helper'

RSpec.describe RecordsController, type: :controller do
  let(:user) { create(:user, handle: 'test.bsky.social', access_token: 'valid_token') }
  let(:record_reader) { instance_double(BlueskyRecordReader) }

  before do
    sign_in user
    allow(BlueskyRecordReader).to receive(:new).with(user).and_return(record_reader)
  end

  describe '#index' do
    let(:collections) { ['app.bsky.feed.post', 'com.whtwnd.blog.entry', 'app.bsky.actor.profile'] }

    before do
      allow(record_reader).to receive(:list_collections).and_return(collections)
    end

    it 'lists available collections' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(assigns(:collections)).to eq(collections)
      expect(BlueskyRecordReader).to have_received(:new).with(user)
      expect(record_reader).to have_received(:list_collections)
    end

    context 'when record reader returns empty collections' do
      before do
        allow(record_reader).to receive(:list_collections).and_return([])
      end

      it 'assigns empty collections' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(assigns(:collections)).to eq([])
      end
    end

    context 'when not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe '#collection' do
    let(:collection_name) { 'com.whtwnd.blog.entry' }
    let(:records) do
      [
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
      ]
    end
    let(:cursor) { 'next_cursor_123' }

    before do
      allow(record_reader).to receive(:list_records).and_return([records, cursor])
    end

    it 'lists records in the collection' do
      get :collection, params: { collection: collection_name }

      expect(response).to have_http_status(:ok)
      expect(assigns(:collection)).to eq(collection_name)
      expect(assigns(:records)).to eq(records)
      expect(assigns(:cursor)).to eq(cursor)
      expect(record_reader).to have_received(:list_records).with(collection_name, limit: 25, cursor: nil)
    end

    it 'accepts custom limit parameter' do
      get :collection, params: { collection: collection_name, limit: 10 }

      expect(record_reader).to have_received(:list_records).with(collection_name, limit: 10, cursor: nil)
    end

    it 'accepts cursor parameter for pagination' do
      get :collection, params: { collection: collection_name, cursor: 'prev_cursor' }

      expect(record_reader).to have_received(:list_records).with(collection_name, limit: 25, cursor: 'prev_cursor')
    end

    it 'limits the maximum limit to 100' do
      get :collection, params: { collection: collection_name, limit: 500 }

      expect(record_reader).to have_received(:list_records).with(collection_name, limit: 100, cursor: nil)
    end

    context 'when collection has no records' do
      before do
        allow(record_reader).to receive(:list_records).and_return([[], nil])
      end

      it 'assigns empty records' do
        get :collection, params: { collection: collection_name }

        expect(assigns(:records)).to eq([])
        expect(assigns(:cursor)).to be_nil
      end
    end

    context 'when collection parameter is missing' do
      it 'raises parameter missing error' do
        expect { get :collection }.to raise_error(ActionController::ParameterMissing)
      end
    end

    context 'when not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to sign in' do
        get :collection, params: { collection: collection_name }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe '#show' do
    let(:collection_name) { 'com.whtwnd.blog.entry' }
    let(:rkey) { 'record123' }
    let(:record) do
      {
        'uri' => 'at://did:plc:test123/com.whtwnd.blog.entry/record123',
        'cid' => 'bafytest123',
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
      allow(record_reader).to receive(:get_record).and_return(record)
    end

    it 'shows the specific record' do
      get :show, params: { collection: collection_name, rkey: rkey }

      expect(response).to have_http_status(:ok)
      expect(assigns(:collection)).to eq(collection_name)
      expect(assigns(:rkey)).to eq(rkey)
      expect(assigns(:record)).to eq(record)
      expect(record_reader).to have_received(:get_record).with(collection_name, rkey)
    end

    context 'when record is not found' do
      before do
        allow(record_reader).to receive(:get_record).and_return(nil)
      end

      it 'renders 404' do
        get :show, params: { collection: collection_name, rkey: 'nonexistent' }

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('Record not found')
      end
    end

    context 'when collection parameter is missing' do
      it 'raises parameter missing error' do
        expect { get :show, params: { rkey: rkey } }.to raise_error(ActionController::ParameterMissing)
      end
    end

    context 'when rkey parameter is missing' do
      it 'raises parameter missing error' do
        expect { get :show, params: { collection: collection_name } }.to raise_error(ActionController::ParameterMissing)
      end
    end

    context 'when not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to sign in' do
        get :show, params: { collection: collection_name, rkey: rkey }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'parameter validation' do
    describe 'collection parameter' do
      it 'accepts valid collection names' do
        allow(record_reader).to receive(:list_records).and_return([[], nil])
        
        valid_collections = [
          'app.bsky.feed.post',
          'com.whtwnd.blog.entry',
          'app.bsky.actor.profile',
          'com.example.custom.type'
        ]

        valid_collections.each do |collection|
          get :collection, params: { collection: collection }
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe 'rkey parameter' do
      before do
        allow(record_reader).to receive(:get_record).and_return(nil)
      end

      it 'accepts valid rkeys' do
        valid_rkeys = [
          'abc123',
          '3k2n4o6p8q',
          'record-with-dashes',
          '2024-01-01T10:00:00Z'
        ]

        valid_rkeys.each do |rkey|
          get :show, params: { collection: 'com.whtwnd.blog.entry', rkey: rkey }
          expect(response).to have_http_status(:not_found) # 404 because record doesn't exist, but request was valid
        end
      end
    end

    describe 'limit parameter' do
      before do
        allow(record_reader).to receive(:list_records).and_return([[], nil])
      end

      it 'accepts valid numeric limits' do
        [1, 25, 50, 100].each do |limit|
          get :collection, params: { collection: 'com.whtwnd.blog.entry', limit: limit }
          expect(response).to have_http_status(:ok)
        end
      end

      it 'handles non-numeric limits gracefully' do
        get :collection, params: { collection: 'com.whtwnd.blog.entry', limit: 'invalid' }
        expect(response).to have_http_status(:ok)
        expect(record_reader).to have_received(:list_records).with('com.whtwnd.blog.entry', limit: 25, cursor: nil)
      end
    end
  end

  describe 'error handling' do
    context 'when BlueskyRecordReader raises an error' do
      before do
        allow(record_reader).to receive(:list_collections).and_raise(StandardError.new('Service error'))
      end

      it 'handles service errors gracefully' do
        expect { get :index }.not_to raise_error
        # The controller should handle the error and render an appropriate response
      end
    end
  end
end
