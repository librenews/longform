require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'validations' do
    subject { build(:post) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }
    it { should validate_length_of(:title).is_at_most(200) }
  end

  describe 'associations' do
    it { should belong_to(:user).required }
    it { should have_rich_text(:content) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(draft: 0, published: 1, archived: 2, failed: 3) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:draft_post) { create(:post, :draft, user: user) }
    let!(:published_post) { create(:post, :published, user: user) }
    let!(:archived_post) { create(:post, :archived, user: user) }

    describe '.recent' do
      it 'returns posts ordered by created_at desc' do
        posts = Post.recent
        expect(posts.first.created_at).to be >= posts.last.created_at
      end
    end

    describe '.search' do
      let!(:searchable_post) { create(:post, title: 'Searchable Title', user: user) }

      it 'finds posts by title' do
        results = Post.search('Searchable')
        expect(results).to include(searchable_post)
      end

      it 'returns all posts when query is blank' do
        results = Post.search('')
        expect(results.count).to eq(Post.count)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }
    let(:draft_post) { create(:post, :draft, user: user) }
    let(:published_post) { create(:post, :published, user: user) }
    let(:failed_post) { create(:post, :failed, user: user) }

    describe '#can_publish?' do
      it 'returns true for draft posts with title and content' do
        expect(draft_post.can_publish?).to be true
      end

      it 'returns true for failed posts with title and content' do
        expect(failed_post.can_publish?).to be true
      end

      it 'returns false for published posts' do
        expect(published_post.can_publish?).to be false
      end

      it 'returns false for posts without content' do
        post = build(:post, content: nil)
        expect(post.can_publish?).to be false
      end

      it 'returns false for posts without title' do
        post = build(:post, title: nil)
        expect(post.can_publish?).to be false
      end
    end

    describe '#publish!' do
      it 'changes status from draft to published' do
        expect { draft_post.publish! }.to change { draft_post.status }.from('draft').to('published')
      end

      it 'sets published_at timestamp' do
        draft_post.publish!
        expect(draft_post.published_at).to be_present
      end

      it 'enqueues PublishToBlueskyJob' do
        expect { draft_post.publish! }.to have_enqueued_job(PublishToBlueskyJob).with(draft_post)
      end

      it 'returns false if post cannot be published' do
        expect(published_post.publish!).to be false
      end
    end

    describe '#unpublish!' do
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
        
        stub_request(:get, %r{https://plc\.directory/did:plc:.*})
          .to_return(status: 200, body: pds_response.to_json, headers: { 'Content-Type' => 'application/json' })

        # Mock successful record deletion
        stub_request(:post, "https://test.pds.host/xrpc/com.atproto.repo.deleteRecord")
          .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
      end
      
      it 'changes status from published to draft' do
        expect { published_post.unpublish! }.to change { published_post.status }.from('published').to('draft')
      end

      it 'clears published_at timestamp' do
        published_post.unpublish!
        expect(published_post.published_at).to be_nil
      end

      it 'clears bluesky_uri' do
        published_post.unpublish!
        expect(published_post.bluesky_uri).to be_nil
      end
    end

    describe '#archive!' do
      it 'changes status to archived' do
        expect { draft_post.archive! }.to change { draft_post.status }.to('archived')
      end
    end

    describe '#word_count' do
      it 'returns word count of plain text content' do
        post = build(:post, content: 'Hello world test content')
        expect(post.word_count).to eq(4)
      end
    end

    describe '#reading_time_minutes' do
      it 'calculates reading time based on word count' do
        post = build(:post)
        allow(post).to receive(:word_count).and_return(400)
        expect(post.reading_time_minutes).to eq(2)
      end

      it 'rounds up to minimum of 1 minute' do
        post = build(:post)
        allow(post).to receive(:word_count).and_return(50)
        expect(post.reading_time_minutes).to eq(1)
      end
    end

    describe '#bluesky_url' do
      it 'returns nil when bluesky_uri is not set' do
        post = build(:post, bluesky_uri: nil)
        expect(post.bluesky_url).to be_nil
      end

      it 'converts AT Protocol URI to web URL for standard posts' do
        user = build(:user, handle: 'test.bsky.social')
        post = build(:post, 
          bluesky_uri: 'at://did:plc:test123/app.bsky.feed.post/abc123',
          user: user
        )
        expect(post.bluesky_url).to eq('https://bsky.app/profile/test.bsky.social/post/abc123')
      end
    end

    describe '#published?' do
      it 'returns true for published posts with published_at' do
        expect(published_post.published?).to be true
      end

      it 'returns false for draft posts' do
        expect(draft_post.published?).to be false
      end
    end

    describe '#draft?' do
      it 'returns true for draft posts' do
        expect(draft_post.draft?).to be true
      end

      it 'returns false for published posts' do
        expect(published_post.draft?).to be false
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save generate_excerpt' do
      it 'generates excerpt from content' do
        content = 'This is a long piece of content that should be truncated to create an excerpt'
        post = build(:post, content: content)
        post.save!
        expect(post.excerpt).to be_present
        expect(post.excerpt.length).to be <= 300
      end

      it 'handles posts with minimal content' do
        post = build(:post, content: 'Short')
        expect { post.save! }.not_to raise_error
        expect(post.excerpt).to eq('Short')
      end
    end
  end

  describe 'factory' do
    it 'creates valid posts' do
      post = build(:post)
      expect(post).to be_valid
    end

    it 'creates posts with different traits' do
      draft = create(:post, :draft)
      published = create(:post, :published)
      archived = create(:post, :archived)
      failed = create(:post, :failed)

      expect(draft.status).to eq('draft')
      expect(published.status).to eq('published')
      expect(archived.status).to eq('archived')
      expect(failed.status).to eq('failed')
    end
  end
end
