require 'rails_helper'

RSpec.describe PostsController, type: :controller do
  let(:user) { create(:user) }
  let(:post) { create(:post, user: user) }
  let(:other_user) { create(:user) }
  let(:other_post) { create(:post, user: other_user) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:draft_post) { create(:post, :draft, user: user) }
    let!(:published_post) { create(:post, :published, user: user) }
    let!(:archived_post) { create(:post, :archived, user: user) }

    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns user posts to @posts' do
      get :index
      expect(assigns(:posts)).to include(draft_post, published_post, archived_post)
    end

    it 'does not include other users posts' do
      other_post # Create other user's post
      get :index
      expect(assigns(:posts)).not_to include(other_post)
    end

    it 'assigns status counts' do
      get :index
      status_counts = assigns(:status_counts)
      
      expect(status_counts[:all]).to eq(3)
      expect(status_counts[:draft]).to eq(1)
      expect(status_counts[:published]).to eq(1)
      expect(status_counts[:archived]).to eq(1)
    end

    context 'with status filter' do
      it 'filters posts by status' do
        get :index, params: { status: 'draft' }
        expect(assigns(:posts)).to include(draft_post)
        expect(assigns(:posts)).not_to include(published_post, archived_post)
      end
    end

    context 'with search query' do
      let!(:matching_post) { create(:post, title: 'Ruby Tutorial', user: user) }
      let!(:non_matching_post) { create(:post, title: 'JavaScript Guide', user: user) }

      it 'filters posts by search query' do
        get :index, params: { search: 'Ruby' }
        expect(assigns(:posts)).to include(matching_post)
        expect(assigns(:posts)).not_to include(non_matching_post)
      end
    end

    context 'pagination' do
      before do
        create_list(:post, 15, user: user)
      end

      it 'paginates results' do
        get :index
        expect(assigns(:posts).count).to eq(10) # Default per_page
      end

      it 'responds to page parameter' do
        get :index, params: { page: 2 }
        expect(response).to be_successful
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: post.id }
      expect(response).to be_successful
    end

    it 'assigns the requested post to @post' do
      get :show, params: { id: post.id }
      expect(assigns(:post)).to eq(post)
    end

    it 'raises error for other users posts' do
      expect {
        get :show, params: { id: other_post.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new post to @post' do
      get :new
      expect(assigns(:post)).to be_a_new(Post)
      expect(assigns(:post).user).to eq(user)
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        title: 'Test Post',
        content: 'This is a test post content.'
      }
    end

    let(:invalid_attributes) do
      {
        title: '',
        content: ''
      }
    end

    context 'with valid parameters' do
      it 'creates a new post' do
        expect {
          post :create, params: { post: valid_attributes }
        }.to change(Post, :count).by(1)
      end

      it 'assigns the post to the current user' do
        post :create, params: { post: valid_attributes }
        expect(assigns(:post).user).to eq(user)
      end

      it 'redirects to the new post' do
        post :create, params: { post: valid_attributes }
        expect(response).to redirect_to(assigns(:post))
      end

      it 'sets a success notice' do
        post :create, params: { post: valid_attributes }
        expect(flash[:notice]).to eq('Post was successfully created.')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new post' do
        expect {
          post :create, params: { post: invalid_attributes }
        }.not_to change(Post, :count)
      end

      it 'renders the new template' do
        post :create, params: { post: invalid_attributes }
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: post.id }
      expect(response).to be_successful
    end

    it 'assigns the requested post to @post' do
      get :edit, params: { id: post.id }
      expect(assigns(:post)).to eq(post)
    end
  end

  describe 'PATCH #update' do
    let(:new_attributes) do
      {
        title: 'Updated Title',
        content: 'Updated content'
      }
    end

    context 'with valid parameters' do
      it 'updates the requested post' do
        patch :update, params: { id: post.id, post: new_attributes }
        post.reload
        expect(post.title).to eq('Updated Title')
        expect(post.content.to_plain_text.strip).to eq('Updated content')
      end

      it 'redirects to the post' do
        patch :update, params: { id: post.id, post: new_attributes }
        expect(response).to redirect_to(post)
      end

      it 'sets a success notice' do
        patch :update, params: { id: post.id, post: new_attributes }
        expect(flash[:notice]).to eq('Post was successfully updated.')
      end

      context 'with AJAX request' do
        it 'returns JSON success response' do
          patch :update, params: { id: post.id, post: new_attributes }, format: :json
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['status']).to eq('success')
        end
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) { { title: '', content: '' } }

      it 'does not update the post' do
        original_title = post.title
        patch :update, params: { id: post.id, post: invalid_attributes }
        post.reload
        expect(post.title).to eq(original_title)
      end

      it 'renders the edit template' do
        patch :update, params: { id: post.id, post: invalid_attributes }
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      context 'with AJAX request' do
        it 'returns JSON error response' do
          patch :update, params: { id: post.id, post: invalid_attributes }, format: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to have_key('errors')
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:post_to_delete) { create(:post, user: user) }

    it 'destroys the requested post' do
      expect {
        delete :destroy, params: { id: post_to_delete.id }
      }.to change(Post, :count).by(-1)
    end

    it 'redirects to posts index' do
      delete :destroy, params: { id: post_to_delete.id }
      expect(response).to redirect_to(posts_path)
    end

    it 'sets a success notice' do
      delete :destroy, params: { id: post_to_delete.id }
      expect(flash[:notice]).to eq('Post was successfully deleted.')
    end
  end

  describe 'PATCH #publish' do
    let(:draft_post) { create(:post, :draft, user: user) }

    before do
      allow_any_instance_of(Post).to receive(:publish!).and_return(true)
    end

    it 'calls publish! on the post' do
      expect_any_instance_of(Post).to receive(:publish!)
      patch :publish, params: { id: draft_post.id }
    end

    context 'when publish succeeds' do
      it 'redirects to the post' do
        patch :publish, params: { id: draft_post.id }
        expect(response).to redirect_to(draft_post)
      end

      it 'sets a success notice' do
        patch :publish, params: { id: draft_post.id }
        expect(flash[:notice]).to eq('Post published to Bluesky!')
      end
    end

    context 'when publish fails' do
      before do
        allow_any_instance_of(Post).to receive(:publish!).and_return(false)
      end

      it 'redirects to the post with an error' do
        patch :publish, params: { id: draft_post.id }
        expect(response).to redirect_to(draft_post)
        expect(flash[:alert]).to eq('Failed to publish post. Please try again.')
      end
    end
  end

  describe 'PATCH #unpublish' do
    let(:published_post) { create(:post, :published, user: user) }

    before do
      allow_any_instance_of(Post).to receive(:unpublish!).and_return(true)
    end

    it 'calls unpublish! on the post' do
      expect_any_instance_of(Post).to receive(:unpublish!)
      patch :unpublish, params: { id: published_post.id }
    end

    context 'when unpublish succeeds' do
      it 'redirects to the post' do
        patch :unpublish, params: { id: published_post.id }
        expect(response).to redirect_to(published_post)
      end

      it 'sets a success notice' do
        patch :unpublish, params: { id: published_post.id }
        expect(flash[:notice]).to eq('Post unpublished and moved to drafts.')
      end
    end

    context 'when unpublish fails' do
      before do
        allow_any_instance_of(Post).to receive(:unpublish!).and_return(false)
      end

      it 'redirects to the post with an error' do
        patch :unpublish, params: { id: published_post.id }
        expect(response).to redirect_to(published_post)
        expect(flash[:alert]).to eq('Failed to unpublish post.')
      end
    end
  end
end

# Helper method for authentication in controller tests
def sign_in(user)
  session[:user_id] = user.id
end
