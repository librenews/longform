require 'rails_helper'

RSpec.describe TokenValidation, type: :controller do
  controller(ApplicationController) do
    include TokenValidation
    
    def index
      render json: { status: 'ok' }
    end
    
    def show
      render json: { status: 'ok' }
    end
    
    def create
      render json: { status: 'created' }
    end
  end

  let(:user) { create(:user, :with_valid_tokens) }
  let(:expired_user) { create(:user, :with_expired_tokens) }

  before do
    # Setup routes for the anonymous controller
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'show' => 'anonymous#show'
      post 'create' => 'anonymous#create'
    end

    # Stub WebMock requests for PDS endpoint resolution
    stub_request(:get, "https://plc.directory/did:plc:ajuCv3ZwNcFNA5rGJVWmzg")
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
    
    # Stub successful token validation
    stub_request(:get, %r{https://.*\.bsky\.network/xrpc/com\.atproto\.server\.getSession})
      .with(headers: { 'Authorization' => /Bearer valid_token/ })
      .to_return(status: 200, body: { "did" => "did:plc:ajuCv3ZwNcFNA5rGJVWmzg" }.to_json)
    
    # Stub expired token validation
    stub_request(:get, %r{https://.*\.bsky\.network/xrpc/com\.atproto\.server\.getSession})
      .with(headers: { 'Authorization' => /Bearer expired_token/ })
      .to_return(status: 401, body: { "error" => "ExpiredToken" }.to_json)
    
    # Stub token refresh endpoint - success case
    stub_request(:post, %r{https://.*\.bsky\.network/xrpc/com\.atproto\.server\.refreshSession})
      .with(headers: { 'Authorization' => /Bearer valid_refresh/ })
      .to_return(status: 200, body: {
        "accessJwt" => "new_access_token",
        "refreshJwt" => "new_refresh_token"
      }.to_json)
    
    # Stub token refresh endpoint - failure case
    stub_request(:post, %r{https://.*\.bsky\.network/xrpc/com\.atproto\.server\.refreshSession})
      .with(headers: { 'Authorization' => /Bearer expired_refresh/ })
      .to_return(status: 401, body: { "error" => "ExpiredToken" }.to_json)
  end

  describe 'token validation' do
    context 'when user has valid tokens' do
      before { sign_in(user) }

      it 'allows access to regular actions' do
        get :index
        expect(response).to be_successful
      end

      it 'allows access to critical actions when token is valid' do
        # Mock successful API validation
        allow_any_instance_of(User).to receive(:pds_endpoint).and_return('https://bsky.social')
        stub_request(:get, "https://bsky.social/xrpc/com.atproto.server.getSession")
          .with(headers: { 'Authorization' => "Bearer #{user.access_token}" })
          .to_return(status: 200, body: '{"did": "test"}')

        post :create
        expect(response).to be_successful
      end
    end

    context 'when user has expired tokens' do
      before { sign_in(expired_user) }

      it 'attempts token refresh when possible' do
        # Mock successful refresh
        allow_any_instance_of(User).to receive(:pds_endpoint).and_return('https://bsky.social')
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.refreshSession")
          .with(headers: { 'Authorization' => "Bearer #{expired_user.refresh_token}" })
          .to_return(
            status: 200,
            body: {
              accessJwt: 'new_access_token',
              refreshJwt: 'new_refresh_token'
            }.to_json
          )

        get :index
        expect(response).to redirect_to(root_path)
        expired_user.reload
        expect(expired_user.access_token).to eq('new_access_token')
      end

      it 'forces logout when refresh fails' do
        # Mock failed refresh
        allow_any_instance_of(User).to receive(:pds_endpoint).and_return('https://bsky.social')
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.refreshSession")
          .with(headers: { 'Authorization' => "Bearer #{expired_user.refresh_token}" })
          .to_return(status: 401, body: '{"error": "Invalid refresh token"}')

        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('session has expired')
        expect(session[:user_id]).to be_nil
      end
    end

    context 'when handling form data preservation' do
      before { sign_in(expired_user) }

      it 'preserves form data during token expiration' do
        # Mock failed token validation
        allow_any_instance_of(TokenValidation).to receive(:verify_token_with_api).and_return(false)
        
        post :create, params: { 
          post: { 
            title: 'Test Post', 
            content: 'Test content' 
          } 
        }

        expect(response).to redirect_to(root_path)
        expect(session[:preserved_form_data]).to be_present
        expect(session[:preserved_form_data][:data][:post][:title]).to eq('Test Post')
        expect(session[:preserved_form_data][:data][:post][:content]).to eq('Test content')
      end

      it 'sets return path for non-AJAX requests' do
        allow_any_instance_of(TokenValidation).to receive(:verify_token_with_api).and_return(false)
        
        get :show
        
        expect(session[:return_to]).to eq('/show')
      end

      it 'handles AJAX requests with JSON response' do
        allow_any_instance_of(TokenValidation).to receive(:verify_token_with_api).and_return(false)
        
        get :index, xhr: true
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Session expired')
        expect(json_response['redirect_url']).to eq(root_path)
      end
    end

    context 'when skipping validation' do
      before { sign_in(expired_user) }

      it 'skips validation for safe read-only actions' do
        # Override the controller to simulate a safe action
        allow(controller).to receive(:skip_token_validation?).and_return(true)
        
        get :show
        expect(response).to be_successful
      end

      it 'skips validation for non-authenticated users' do
        session[:user_id] = nil
        
        get :index
        expect(response).to be_successful
      end
    end
  end

  describe 'critical action detection' do
    it 'identifies publish actions as critical' do
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(action: 'publish'))
      expect(controller.send(:critical_action?)).to be true
    end

    it 'identifies post creation as critical' do
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(action: 'create', controller: 'posts'))
      expect(controller.send(:critical_action?)).to be true
    end

    it 'does not identify read actions as critical' do
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(action: 'index'))
      allow(controller).to receive(:request).and_return(double(get?: true))
      expect(controller.send(:critical_action?)).to be false
    end
  end

  describe 'form data preservation rules' do
    it 'preserves post form data' do
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(controller: 'posts', action: 'create'))
      expect(controller.send(:should_preserve_form_data?)).to be true
    end

    it 'preserves comment form data' do
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(controller: 'comments', action: 'create'))
      expect(controller.send(:should_preserve_form_data?)).to be true
    end

    it 'does not preserve data for other controllers' do
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(controller: 'sessions', action: 'create'))
      expect(controller.send(:should_preserve_form_data?)).to be false
    end
  end
end
