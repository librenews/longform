require 'rails_helper'

RSpec.describe ProfilesController, type: :request do
  let(:user) { create(:user, :with_valid_tokens, handle: 'testuser.bsky.social') }
  
  before do
    # Stub WebMock requests for AT Protocol calls
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

    # Stub the listRecords call for blog entries
    stub_request(:get, %r{https://.*\.bsky\.network/xrpc/com\.atproto\.repo\.listRecords})
      .with(query: hash_including('collection' => 'com.whtwnd.blog.entry'))
      .to_return(
        status: 200,
        body: {
          "records" => [
            {
              "uri" => "at://did:plc:test/com.whtwnd.blog.entry/123",
              "cid" => "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
              "value" => {
                "title" => "Test Blog Post",
                "content" => "This is a test blog post from Bluesky AT Protocol",
                "createdAt" => "2025-08-04T12:00:00Z",
                "visibility" => "public"
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe 'GET /profile/:handle' do
    context 'when user exists' do
      it 'displays the user profile' do
        get profile_path(user.handle)
        
        expect(response).to be_successful
        expect(response.body).to include(user.handle)
        expect(response.body).to include("Test Blog Post")
      end

      it 'shows Bluesky profile link' do
        get profile_path(user.handle)
        
        expect(response.body).to include("bsky.app/profile/#{user.handle}")
      end
    end

    context 'when user does not exist' do
      it 'redirects to root with an alert' do
        get profile_path('nonexistent.bsky.social')
        
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("User not found")
      end
    end
  end
end
