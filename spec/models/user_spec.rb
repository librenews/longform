require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:handle) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:provider) }
    it { should validate_presence_of(:uid) }
    it { should validate_presence_of(:access_token) }
    
    it { should validate_uniqueness_of(:handle) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_uniqueness_of(:uid).scoped_to(:provider) }
  end

  describe 'associations' do
    it { should have_many(:posts).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'sets display_name from handle if not provided' do
      user = build(:user, display_name: nil, handle: 'testuser')
      user.save!
      expect(user.display_name).to eq('testuser')
    end

    it 'does not override provided display_name' do
      user = build(:user, display_name: 'Test User', handle: 'testuser')
      user.save!
      expect(user.display_name).to eq('Test User')
    end
  end

  describe '.from_omniauth' do
    let(:auth_hash) do
      {
        'provider' => 'bluesky',
        'uid' => 'test.bsky.social',
        'info' => {
          'handle' => 'testuser',
          'email' => 'test@example.com',
          'name' => 'Test User',
          'image' => 'https://example.com/avatar.jpg'
        },
        'credentials' => {
          'token' => 'access_token_123',
          'refresh_token' => 'refresh_token_123',
          'expires_at' => 1.hour.from_now.to_i
        }
      }
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect {
          User.from_omniauth(auth_hash)
        }.to change(User, :count).by(1)
      end

      it 'sets all attributes correctly' do
        user = User.from_omniauth(auth_hash)
        
        expect(user.provider).to eq('bluesky')
        expect(user.uid).to eq('test.bsky.social')
        expect(user.handle).to eq('testuser')
        expect(user.email).to eq('test@example.com')
        expect(user.display_name).to eq('Test User')
        expect(user.avatar_url).to eq('https://example.com/avatar.jpg')
        expect(user.access_token).to eq('access_token_123')
        expect(user.refresh_token).to eq('refresh_token_123')
        expect(user.token_expires_at).to be_within(1.second).of(Time.at(auth_hash['credentials']['expires_at']))
      end
    end

    context 'when user already exists' do
      let!(:existing_user) { create(:user, provider: 'bluesky', uid: 'test.bsky.social') }

      it 'does not create a new user' do
        expect {
          User.from_omniauth(auth_hash)
        }.not_to change(User, :count)
      end

      it 'updates existing user attributes' do
        user = User.from_omniauth(auth_hash)
        
        expect(user.id).to eq(existing_user.id)
        expect(user.handle).to eq('testuser')
        expect(user.email).to eq('test@example.com')
        expect(user.display_name).to eq('Test User')
        expect(user.access_token).to eq('access_token_123')
      end
    end
  end

  describe '#display_name' do
    it 'returns the display name when set' do
      user = build(:user, display_name: 'John Doe')
      expect(user.display_name).to eq('John Doe')
    end

    it 'returns the handle when display name is not set' do
      user = build(:user, display_name: nil, handle: 'johndoe')
      expect(user.display_name).to eq('johndoe')
    end
  end

  describe '#tokens_valid?' do
    it 'returns true when tokens have not expired' do
      user = build(:user, :fresh_tokens)
      expect(user.tokens_valid?).to be true
    end

    it 'returns false when tokens have expired' do
      user = build(:user, :expired_tokens)
      expect(user.tokens_valid?).to be false
    end

    it 'returns false when token_expires_at is nil' do
      user = build(:user, token_expires_at: nil)
      expect(user.tokens_valid?).to be false
    end
  end

  describe '#published_posts' do
    let(:user) { create(:user) }
    let!(:published_post) { create(:post, :published, user: user) }
    let!(:draft_post) { create(:post, :draft, user: user) }
    let!(:archived_post) { create(:post, :archived, user: user) }

    it 'returns only published posts' do
      expect(user.published_posts).to contain_exactly(published_post)
    end
  end

  describe '#draft_posts' do
    let(:user) { create(:user) }
    let!(:published_post) { create(:post, :published, user: user) }
    let!(:draft_post) { create(:post, :draft, user: user) }
    let!(:archived_post) { create(:post, :archived, user: user) }

    it 'returns only draft posts' do
      expect(user.draft_posts).to contain_exactly(draft_post)
    end
  end

  describe '#total_word_count' do
    let(:user) { create(:user) }

    before do
      create(:post, user: user, content: 'This is a test post with ten words exactly here')
      create(:post, user: user, content: 'Another post with five words')
    end

    it 'returns the total word count across all posts' do
      expect(user.total_word_count).to eq(15)
    end
  end

  describe 'statistics methods' do
    let(:user) { create(:user) }

    before do
      create_list(:post, 3, :published, user: user)
      create_list(:post, 2, :draft, user: user)
      create_list(:post, 1, :archived, user: user)
    end

    describe '#posts_count' do
      it 'returns total number of posts' do
        expect(user.posts_count).to eq(6)
      end
    end

    describe '#published_posts_count' do
      it 'returns number of published posts' do
        expect(user.published_posts_count).to eq(3)
      end
    end

    describe '#draft_posts_count' do
      it 'returns number of draft posts' do
        expect(user.draft_posts_count).to eq(2)
      end
    end
  end
end
