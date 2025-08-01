require 'rails_helper'

RSpec.describe 'AT Protocol Publishing Workflow', type: :feature do
  let(:user) { create(:user, handle: 'test.bsky.social', access_token: 'valid_token') }
  let(:post) { create(:post, :draft, user: user, title: 'Integration Test Post', content: '<h1>Test</h1><p>Content</p>') }

  before do
    sign_in user
  end

  describe 'Publishing a blog post' do
    context 'successful publishing workflow' do
      before do
        stub_at_protocol_success(handle: user.handle)
      end

      it 'publishes post to AT Protocol with Whitewind lexicon' do
        visit post_path(post)
        
        expect(page).to have_content('Integration Test Post')
        expect(page).to have_button('Publish to Bluesky')
        
        # Mock the background job to run immediately
        perform_enqueued_jobs do
          click_button 'Publish to Bluesky'
        end
        
        # Verify the post was updated
        post.reload
        expect(post.status).to eq('published')
        expect(post.bluesky_url).to be_present
        expect(post.published_at).to be_present
        
        # Verify the correct API calls were made
        expect_blog_entry_creation('test.pds.host',
          title: 'Integration Test Post',
          content_includes: ['# Test']
        )
      end

      it 'handles republishing failed posts' do
        failed_post = create(:post, :failed, user: user)
        
        visit post_path(failed_post)
        
        expect(page).to have_button('Publish to Bluesky')
        
        perform_enqueued_jobs do
          click_button 'Publish to Bluesky'
        end
        
        failed_post.reload
        expect(failed_post.status).to eq('published')
      end
    end

    context 'publishing failure scenarios' do
      before do
        stub_at_protocol_failure(handle: user.handle)
      end

      it 'marks post as failed when AT Protocol request fails' do
        visit post_path(post)
        
        perform_enqueued_jobs do
          click_button 'Publish to Bluesky'
        end
        
        post.reload
        expect(post.status).to eq('failed')
        expect(post.bluesky_url).to be_nil
      end
    end
  end

  describe 'Records Browser' do
    before do
      stub_records_browser(handle: user.handle)
    end

    it 'allows browsing AT Protocol collections' do
      visit records_path
      
      expect(page).to have_content('AT Protocol Records')
      expect(page).to have_link('com.whtwnd.blog.entry')
      expect(page).to have_link('app.bsky.feed.post')
      
      click_link 'com.whtwnd.blog.entry'
      
      expect(page).to have_content('Records in com.whtwnd.blog.entry')
      expect(page).to have_content('Test Blog Post')
      expect(page).to have_content('Another Blog Post')
    end

    it 'allows viewing individual records' do
      visit collection_records_path('com.whtwnd.blog.entry')
      
      click_link 'View', match: :first
      
      expect(page).to have_content('Record Details')
      expect(page).to have_content('com.whtwnd.blog.entry')
      expect(page).to have_content('Test Blog Post')
    end

    it 'handles pagination in collection view' do
      visit collection_records_path('com.whtwnd.blog.entry')
      
      expect(page).to have_link('Next')
      
      click_link 'Next'
      
      expect(current_url).to include('cursor=')
    end
  end

  describe 'Post Management' do
    let(:published_post) { create(:post, :published, user: user, bluesky_url: 'https://example.com/test') }

    it 'allows unpublishing posts' do
      visit post_path(published_post)
      
      expect(page).to have_button('Unpublish')
      
      click_button 'Unpublish'
      
      published_post.reload
      expect(published_post.status).to eq('draft')
      expect(published_post.bluesky_url).to be_nil
      expect(published_post.published_at).to be_nil
    end

    it 'allows archiving posts' do
      visit post_path(published_post)
      
      expect(page).to have_button('Archive')
      
      click_button 'Archive'
      
      published_post.reload
      expect(published_post.status).to eq('archived')
    end
  end

  describe 'Content conversion' do
    let(:rich_post) do
      create(:post, :draft, user: user, 
        title: 'Rich Content Test',
        content: <<~HTML
          <h1>Main Heading</h1>
          <p>Paragraph with <strong>bold</strong> and <em>italic</em> text.</p>
          <ul>
            <li>List item 1</li>
            <li>List item 2</li>
          </ul>
          <blockquote>Quote text</blockquote>
          <pre><code>code block</code></pre>
        HTML
      )
    end

    before do
      stub_at_protocol_success(handle: user.handle)
    end

    it 'converts HTML to Markdown for AT Protocol' do
      visit post_path(rich_post)
      
      perform_enqueued_jobs do
        click_button 'Publish to Bluesky'
      end
      
      # Verify markdown conversion in the API call
      expect_blog_entry_creation('test.pds.host',
        title: 'Rich Content Test',
        content_includes: ['# Main Heading', '**bold**', '*italic*', '- List item 1', '> Quote text']
      )
    end
  end
end
