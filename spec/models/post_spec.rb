require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'validations' do
    subject { build(:post) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:user) }
    it { should validate_presence_of(:status) }

    it { should validate_length_of(:title).is_at_most(255) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_rich_text(:content) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(draft: 0, published: 1, archived: 2, failed: 3) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:recent_post) { create(:post, :recent, user: user) }
    let!(:old_post) { create(:post, :old, user: user) }
    let!(:published_post) { create(:post, :published, user: user) }
    let!(:draft_post) { create(:post, :draft, user: user) }

    describe '.recent' do
      it 'returns posts ordered by created_at desc' do
        expect(Post.recent).to eq([recent_post, published_post, draft_post, old_post])
      end
    end

    describe '.published' do
      it 'returns only published posts' do
        expect(Post.published).to contain_exactly(published_post)
      end
    end

    describe '.drafts' do
      it 'returns only draft posts' do
        expect(Post.drafts).to contain_exactly(draft_post)
      end
    end

    describe '.search' do
      let!(:matching_title) { create(:post, title: 'Ruby on Rails Tutorial') }
      let!(:matching_content) { create(:post, content: 'This post talks about Ruby programming') }
      let!(:no_match) { create(:post, title: 'JavaScript Guide', content: 'All about JS') }

      it 'finds posts by title' do
        results = Post.search('Ruby')
        expect(results).to include(matching_title, matching_content)
        expect(results).not_to include(no_match)
      end

      it 'finds posts by content' do
        results = Post.search('programming')
        expect(results).to include(matching_content)
        expect(results).not_to include(matching_title, no_match)
      end

      it 'is case insensitive' do
        results = Post.search('ruby')
        expect(results).to include(matching_title, matching_content)
      end

      it 'returns all posts when query is blank' do
        expect(Post.search('').count).to eq(Post.count)
        expect(Post.search(nil).count).to eq(Post.count)
      end
    end
  end

  describe '#word_count' do
    it 'counts words in content correctly' do
      post = build(:post, content: 'This is a test post with exactly ten words here')
      expect(post.word_count).to eq(10)
    end

    it 'handles empty content' do
      post = build(:post, content: '')
      expect(post.word_count).to eq(0)
    end

    it 'handles content with multiple spaces and newlines' do
      post = build(:post, content: "Word1\n\nWord2   Word3\t\tWord4")
      expect(post.word_count).to eq(4)
    end

    it 'strips HTML tags from rich text content' do
      post = build(:post)
      # Simulate ActionText rich content with HTML
      allow(post.content).to receive(:to_plain_text).and_return('Five words in plain text')
      expect(post.word_count).to eq(5)
    end
  end

  describe '#reading_time_minutes' do
    it 'calculates reading time based on 200 words per minute' do
      post = build(:post)
      allow(post).to receive(:word_count).and_return(400)
      expect(post.reading_time_minutes).to eq(2)
    end

    it 'returns minimum of 1 minute for short posts' do
      post = build(:post)
      allow(post).to receive(:word_count).and_return(50)
      expect(post.reading_time_minutes).to eq(1)
    end

    it 'rounds up fractional minutes' do
      post = build(:post)
      allow(post).to receive(:word_count).and_return(250) # 1.25 minutes
      expect(post.reading_time_minutes).to eq(2)
    end
  end

  describe '#excerpt' do
    it 'returns first 150 characters of content' do
      long_content = 'A' * 200
      post = build(:post, content: long_content)
      allow(post.content).to receive(:to_plain_text).and_return(long_content)
      
      expect(post.excerpt.length).to eq(153) # 150 + "..."
      expect(post.excerpt).to end_with('...')
    end

    it 'returns full content if shorter than 150 characters' do
      short_content = 'This is a short post'
      post = build(:post, content: short_content)
      allow(post.content).to receive(:to_plain_text).and_return(short_content)
      
      expect(post.excerpt).to eq(short_content)
    end

    it 'handles empty content' do
      post = build(:post, content: '')
      allow(post.content).to receive(:to_plain_text).and_return('')
      expect(post.excerpt).to eq('')
    end
  end

  describe '#can_publish?' do
    it 'returns true for draft posts with title and content' do
      post = build(:post, :draft, title: 'Test Title', content: 'Test content')
      expect(post.can_publish?).to be true
    end

    it 'returns true for published posts (for updates)' do
      post = build(:post, :published)
      expect(post.can_publish?).to be true
    end

    it 'returns false for posts without title' do
      post = build(:post, :draft, title: '', content: 'Test content')
      expect(post.can_publish?).to be false
    end

    it 'returns false for posts without content' do
      post = build(:post, :draft, title: 'Test Title', content: '')
      expect(post.can_publish?).to be false
    end

    it 'returns false for archived posts' do
      post = build(:post, :archived)
      expect(post.can_publish?).to be false
    end

    it 'returns false for failed posts' do
      post = build(:post, :failed)
      expect(post.can_publish?).to be false
    end
  end

  describe '#publish!' do
    let(:user) { create(:user) }
    let(:post) { create(:post, :draft, user: user) }

    before do
      # Mock the background job
      allow(PublishToBlueskyJob).to receive(:perform_later)
    end

    it 'changes status to published' do
      expect { post.publish! }.to change(post, :status).from('draft').to('published')
    end

    it 'sets published_at timestamp' do
      freeze_time do
        post.publish!
        expect(post.published_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'enqueues background job to publish to Bluesky' do
      post.publish!
      expect(PublishToBlueskyJob).to have_received(:perform_later).with(post)
    end

    it 'saves the post' do
      post.publish!
      expect(post).to be_persisted
      expect(post.reload.status).to eq('published')
    end

    context 'when post cannot be published' do
      before do
        post.update!(title: '')
      end

      it 'does not change status' do
        expect { post.publish! }.not_to change(post, :status)
      end

      it 'does not enqueue background job' do
        post.publish!
        expect(PublishToBlueskyJob).not_to have_received(:perform_later)
      end
    end
  end

  describe '#unpublish!' do
    let(:post) { create(:post, :published) }

    it 'changes status to draft' do
      expect { post.unpublish! }.to change(post, :status).from('published').to('draft')
    end

    it 'clears published_at timestamp' do
      post.unpublish!
      expect(post.published_at).to be_nil
    end

    it 'clears bluesky_url' do
      post.update!(bluesky_url: 'https://example.com/post')
      post.unpublish!
      expect(post.bluesky_url).to be_nil
    end

    it 'saves the post' do
      post.unpublish!
      expect(post.reload.status).to eq('draft')
    end
  end

  describe '#mark_as_failed!' do
    let(:post) { create(:post, :published) }

    it 'changes status to failed' do
      expect { post.mark_as_failed! }.to change(post, :status).from('published').to('failed')
    end

    it 'clears published_at timestamp' do
      post.mark_as_failed!
      expect(post.published_at).to be_nil
    end

    it 'clears bluesky_url' do
      post.update!(bluesky_url: 'https://example.com/post')
      post.mark_as_failed!
      expect(post.bluesky_url).to be_nil
    end

    it 'saves the post' do
      post.mark_as_failed!
      expect(post.reload.status).to eq('failed')
    end
  end

  describe 'callbacks' do
    describe 'before_save' do
      it 'updates word_count when content changes' do
        post = create(:post, content: 'Original content with five words')
        original_count = post.word_count
        
        post.update!(content: 'New content')
        expect(post.word_count).not_to eq(original_count)
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
      long = create(:post, :long)

      expect(draft.status).to eq('draft')
      expect(published.status).to eq('published')
      expect(published.published_at).to be_present
      expect(long.word_count).to be > 100
    end
  end
end
