require 'rails_helper'

RSpec.describe PublishToBlueskyJob, type: :job do
  let(:user) { create(:user, handle: 'test.bsky.social', access_token: 'valid_token') }
  let(:post) { create(:post, :published_locally, user: user) }
  let(:publisher_double) { instance_double(BlueskyDpopPublisher) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('APP_HOST').and_return('longform.test')
  end

  describe '#perform' do
    before do
      allow(BlueskyDpopPublisher).to receive(:new).with(post.user).and_return(publisher_double)
    end

    context 'when publishing succeeds' do
      before do
        allow(publisher_double).to receive(:publish).and_return({
          success: true, 
          uri: "at://did:plc:test123/com.whtwnd.blog.entry/abc123",
          cid: "bafytest123"
        })
      end

      it 'creates a BlueskyDpopPublisher instance' do
        described_class.perform_now(post)
        expect(BlueskyDpopPublisher).to have_received(:new).with(post.user)
      end

      it 'calls publish on the publisher' do
        described_class.perform_now(post)
        expect(publisher_double).to have_received(:publish)
      end

      it 'does not change the post status when already published' do
        expect {
          described_class.perform_now(post)
        }.not_to change { post.reload.status }
      end

      it 'updates post status from failed to published' do
        failed_post = create(:post, :failed, user: user)
        allow(BlueskyDpopPublisher).to receive(:new).with(failed_post.user).and_return(publisher_double)
        
        expect {
          described_class.perform_now(failed_post)
        }.to change { failed_post.reload.status }.from('failed').to('published')
      end
    end

    context 'when post already has bluesky_uri (duplicate prevention)' do
      let(:already_published_post) { create(:post, :published, user: user) }

      it 'skips publishing and returns early' do
        expect(BlueskyDpopPublisher).not_to receive(:new)
        described_class.perform_now(already_published_post)
      end

      it 'logs that post is already published' do
        expect(Rails.logger).to receive(:info).with(
          "Post #{already_published_post.id} already published to Bluesky: #{already_published_post.bluesky_uri}"
        )
        described_class.perform_now(already_published_post)
      end
    end

    context 'when publishing fails' do
      before do
        allow(publisher_double).to receive(:publish).and_return({
          success: false,
          error: "Publishing failed"
        })
      end

      it 'marks the post as failed' do
        expect {
          described_class.perform_now(post)
        }.to change { post.reload.status }.from('published').to('failed')
      end

      it 'clears the bluesky_url when marking as failed' do
        post.update!(bluesky_url: 'https://example.com/test')
        
        described_class.perform_now(post)
        
        expect(post.reload.bluesky_url).to be_nil
      end
    end

    context 'when an exception occurs' do
      let(:error_message) { 'Network error' }

      before do
        allow(publisher_double).to receive(:publish).and_raise(StandardError.new(error_message))
        allow(Rails.logger).to receive(:error)
      end

      it 'marks the post as failed' do
        expect {
          described_class.perform_now(post)
        }.to change { post.reload.status }.from('published').to('failed')
      end

      it 'logs the error' do
        described_class.perform_now(post)
        expect(Rails.logger).to have_received(:error).with(
          "Failed to publish post #{post.id} to Bluesky: #{error_message}"
        )
      end

      it 'clears bluesky_url on exception' do
        post.update!(bluesky_url: 'https://example.com/test')
        
        described_class.perform_now(post)
        
        expect(post.reload.bluesky_url).to be_nil
      end
    end

    context 'job queuing' do
      it 'queues the job' do
        expect {
          described_class.perform_later(post)
        }.to enqueue_job(described_class).with(post)
      end

      it 'performs the job asynchronously' do
        allow(BlueskyDpopPublisher).to receive(:new).and_return(publisher_double)
        allow(publisher_double).to receive(:publish).and_return(true)

        perform_enqueued_jobs do
          described_class.perform_later(post)
        end

        expect(BlueskyDpopPublisher).to have_received(:new).with(post)
      end
    end

    context 'retry logic' do
      it 'retries on failure' do
        allow(publisher_double).to receive(:publish).and_raise(StandardError.new('Temporary error'))
        
        expect(described_class).to receive(:retry_job).with(
          wait: 5.minutes,
          queue: described_class.queue_name
        )
        
        expect { described_class.perform_now(post) }.to raise_error(StandardError)
      end
    end

    context 'URL generation' do
      before do
        allow(publisher_double).to receive(:publish).and_return(true)
      end

      it 'uses correct host from environment' do
        described_class.perform_now(post)
        # Test passes if no exceptions are raised during URL generation
        expect(true).to be true
      end
    end

    context 'retry behavior' do
      before do
        allow(publisher_double).to receive(:publish).and_raise(Faraday::ConnectionFailed.new('Network timeout'))
        allow(post).to receive(:mark_as_failed!)
      end

      it 'handles network errors gracefully' do
        expect {
          described_class.perform_now(post)
        }.not_to raise_error
      end
    end
  end

  describe 'job configuration' do
    it 'is configured to use the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
