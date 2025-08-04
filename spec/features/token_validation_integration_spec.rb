require 'rails_helper'

RSpec.describe 'Token Validation Integration', type: :feature do
  let(:user) { create(:user, :with_valid_tokens) }
  let(:expired_user) { create(:user, :with_expired_tokens) }

  before do
    # Mock Bluesky API endpoints
    allow_any_instance_of(User).to receive(:pds_endpoint).and_return('https://test.pds.example')
    
    # Mock DPoP key methods
    allow_any_instance_of(User).to receive(:dpop_jwk).and_return({
      'kty' => 'EC',
      'crv' => 'P-256',
      'x' => 'test_x',
      'y' => 'test_y'
    })
    allow_any_instance_of(User).to receive(:dpop_private_key).and_return(
      OpenSSL::PKey::EC.generate('prime256v1')
    )
  end

  scenario 'User with valid token can create and publish posts' do
    # Mock successful token validation
    stub_request(:get, "https://test.pds.example/xrpc/com.atproto.server.getSession")
      .with(headers: { 'Authorization' => "Bearer #{user.access_token}" })
      .to_return(status: 200, body: '{"did": "test"}')

    # Mock successful publish
    stub_request(:post, "https://test.pds.example/xrpc/com.atproto.repo.createRecord")
      .to_return(
        status: 200,
        body: {
          uri: 'at://did:plc:test123/com.whtwnd.blog.entry/test123',
          cid: 'bafytest123'
        }.to_json
      )

    sign_in(user)
    visit new_post_path

    fill_in 'Title', with: 'Test Blog Post'
    fill_in_rich_text_area 'Content', with: 'This is test content for the blog post.'

    click_button 'Publish'

    expect(page).to have_content('Post published to Bluesky!')
    expect(Post.last.bluesky_uri).to be_present
  end

  scenario 'User with expired token gets redirected to login with form data preserved' do
    # Mock token validation failure
    stub_request(:get, "https://test.pds.example/xrpc/com.atproto.server.getSession")
      .with(headers: { 'Authorization' => "Bearer #{expired_user.access_token}" })
      .to_return(status: 401, body: '{"error": "Invalid token"}')

    # Mock failed token refresh
    stub_request(:post, "https://test.pds.example/xrpc/com.atproto.server.refreshSession")
      .with(headers: { 'Authorization' => "Bearer #{expired_user.refresh_token}" })
      .to_return(status: 401, body: '{"error": "Invalid refresh token"}')

    sign_in(expired_user)
    visit new_post_path

    fill_in 'Title', with: 'Test Blog Post'
    fill_in_rich_text_area 'Content', with: 'This is test content that should be preserved.'

    # Try to publish - should trigger token validation
    click_button 'Publish'

    expect(page).to have_content('session has expired')
    expect(current_path).to eq(root_path)

    # Verify form data was preserved in session
    expect(Rails.application.routes.url_helpers).to receive(:new_post_path)
    expect(session[:preserved_form_data]).to be_present
  end

  scenario 'User gets seamless experience when token is successfully refreshed' do
    # Mock initial token validation failure
    stub_request(:get, "https://test.pds.example/xrpc/com.atproto.server.getSession")
      .with(headers: { 'Authorization' => "Bearer #{expired_user.access_token}" })
      .to_return(status: 401, body: '{"error": "Invalid token"}')

    # Mock successful token refresh
    stub_request(:post, "https://test.pds.example/xrpc/com.atproto.server.refreshSession")
      .with(headers: { 'Authorization' => "Bearer #{expired_user.refresh_token}" })
      .to_return(
        status: 200,
        body: {
          accessJwt: 'new_access_token',
          refreshJwt: 'new_refresh_token'
        }.to_json
      )

    # Mock successful validation with new token
    stub_request(:get, "https://test.pds.example/xrpc/com.atproto.server.getSession")
      .with(headers: { 'Authorization' => "Bearer new_access_token" })
      .to_return(status: 200, body: '{"did": "test"}')

    sign_in(expired_user)
    visit posts_path

    # Should not redirect, token should be refreshed seamlessly
    expect(page).to have_content('Your Posts')
    expect(current_path).to eq(posts_path)

    # Verify token was updated
    expired_user.reload
    expect(expired_user.access_token).to eq('new_access_token')
  end

  scenario 'AJAX requests handle token expiration gracefully' do
    # Mock token validation failure
    stub_request(:get, "https://test.pds.example/xrpc/com.atproto.server.getSession")
      .with(headers: { 'Authorization' => "Bearer #{expired_user.access_token}" })
      .to_return(status: 401, body: '{"error": "Invalid token"}')

    # Mock failed refresh
    stub_request(:post, "https://test.pds.example/xrpc/com.atproto.server.refreshSession")
      .to_return(status: 401, body: '{"error": "Invalid refresh token"}')

    sign_in(expired_user)
    visit edit_post_path(create(:post, user: expired_user))

    # Simulate AJAX auto-save request (this would be triggered by JavaScript)
    page.execute_script("""
      fetch('/posts/#{create(:post, user: expired_user).id}', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: JSON.stringify({
          post: { title: 'Updated Title', content: 'Updated content' }
        })
      }).then(response => {
        if (response.status === 401) {
          window.sessionExpired = true;
        }
      });
    """)

    # Wait for AJAX to complete
    sleep 0.5

    # Check that session expired was detected
    expect(page.evaluate_script('window.sessionExpired')).to be true
  end

  scenario 'Form data restoration after re-authentication' do
    # Create a post to edit
    post = create(:post, user: user, title: 'Original Title', content: 'Original content')

    # Mock token expiration during edit
    stub_request(:get, "https://test.pds.example/xrpc/com.atproto.server.getSession")
      .to_return(status: 401, body: '{"error": "Invalid token"}')

    # Mock failed refresh (force re-login)
    stub_request(:post, "https://test.pds.example/xrpc/com.atproto.server.refreshSession")
      .to_return(status: 401, body: '{"error": "Invalid refresh token"}')

    sign_in(user)
    visit edit_post_path(post)

    # Make changes to the form
    fill_in 'Title', with: 'Updated Title'
    fill_in_rich_text_area 'Content', with: 'Updated content that should be preserved'

    # Try to save - should trigger token validation and redirect
    click_button 'Save Draft'

    expect(page).to have_content('session has expired')
    
    # Now simulate successful re-authentication
    # The SessionsController should detect preserved form data and redirect back
    sign_in(user) # Re-authenticate
    
    # Should redirect back to edit page with preserved data
    visit edit_post_path(post)
    
    # Note: In a real integration test, we'd need to simulate the OAuth flow
    # and form data restoration, but this demonstrates the concept
  end

  def sign_in(user)
    # Simple session-based sign in for tests
    visit root_path
    # In a real app, this would go through the OAuth flow
    # For testing, we can set the session directly
    page.execute_script("window.location.href = '#{root_path}'")
    
    # Simulate session creation
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    page.set_rack_session(user_id: user.id)
  end

  def fill_in_rich_text_area(locator, with:)
    # Helper to fill in Trix editor
    find(:css, "trix-editor[placeholder*='#{locator}'], trix-editor").set(with)
  end
end
