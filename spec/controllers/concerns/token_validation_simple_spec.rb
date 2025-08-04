require 'rails_helper'

RSpec.describe TokenValidation, type: :controller do
  controller(ApplicationController) do
    def index
      render json: { status: 'ok' }
    end
    
    def create
      render json: { status: 'created' }
    end
  end

  let(:user) { create(:user, :with_valid_tokens) }
  let(:expired_user) { create(:user, :with_expired_tokens) }

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      post 'create' => 'anonymous#create'
    end

    # Stub all WebMock requests for PDS endpoint resolution
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

    # Stub token validation requests
    stub_request(:get, /xrpc\/com\.atproto\.server\.getSession/)
      .to_return(status: 200, body: { "did" => "did:plc:test" }.to_json)
  end

  describe 'token validation' do
    context 'when user has valid tokens' do
      before { session[:user_id] = user.id }

      it 'allows access to regular actions' do
        get :index
        expect(response).to be_successful
      end

      it 'allows access to critical actions when token is valid' do
        allow(user).to receive(:has_valid_bluesky_token?).and_return(true)
        allow(User).to receive(:find).with(user.id).and_return(user)
        
        post :create
        expect(response).to be_successful
      end
    end

    context 'when user has expired tokens' do
      before { session[:user_id] = expired_user.id }

      it 'redirects to root when token validation fails' do
        # Mock token validation to fail
        allow(expired_user).to receive(:has_valid_bluesky_token?).and_return(false)
        allow(expired_user).to receive(:refresh_token).and_return(nil)
        allow(User).to receive(:find).with(expired_user.id).and_return(expired_user)
        
        post :create
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when handling form data preservation' do
      before { session[:user_id] = expired_user.id }

      it 'preserves form data during token expiration' do
        allow(expired_user).to receive(:has_valid_bluesky_token?).and_return(false)
        allow(expired_user).to receive(:refresh_token).and_return(nil)
        allow(User).to receive(:find).with(expired_user.id).and_return(expired_user)
        
        # Mock the params to look like we're creating a post
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new({
            controller: 'posts',
            action: 'create',
            post: { title: 'Test', content: 'Content' }
          })
        )
        
        post :create, params: { post: { title: 'Test', content: 'Content' } }
        
        expect(response).to redirect_to(root_path)
        expect(session[:preserved_form_data]).to be_present
        expect(session[:preserved_form_data][:data][:post][:title]).to eq('Test')
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to root path' do
        post :create
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'critical action detection' do
    let(:mock_request) { double('request') }
    
    before do
      allow(controller).to receive(:request).and_return(mock_request)
    end

    it 'identifies create action for posts as critical' do
      allow(controller).to receive(:params).and_return({ controller: 'posts', action: 'create' })
      
      expect(controller.send(:critical_action?)).to be true
    end

    it 'identifies publish action as critical' do
      allow(controller).to receive(:params).and_return({ action: 'publish' })
      
      expect(controller.send(:critical_action?)).to be true
    end

    it 'identifies post requests to records as critical' do
      allow(mock_request).to receive(:post?).and_return(true)
      allow(controller).to receive(:params).and_return({ controller: 'records' })
      
      expect(controller.send(:critical_action?)).to be true
    end

    it 'does not identify index actions as critical' do
      allow(mock_request).to receive(:post?).and_return(false)
      allow(controller).to receive(:params).and_return({ controller: 'posts', action: 'index' })
      
      expect(controller.send(:critical_action?)).to be false
    end
  end
end
