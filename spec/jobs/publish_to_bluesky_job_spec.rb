require 'rails_helper'

RSpec.describe PublishToBlueskyJob, type: :job do
  let(:user) { create(:user) }
  let(:post) { create(:post, :published, user: user) }
  let(:publisher_double) { instance_double(BlueskyPublisher) }

  describe '#perform' do
    before do
      allow(BlueskyPublisher).to receive(:new).with(post).and_return(publisher_double)
    end

    context 'when publishing succeeds' do
      before do
        allow(publisher_double).to receive(:publish).and_return(true)
      end

      it 'creates a BlueskyPublisher instance' do
        described_class.perform_now(post)
        expect(BlueskyPublisher).to have_received(:new).with(post)
      end

      it 'calls publish on the publisher' do
        described_class.perform_now(post)
        expect(publisher_double).to have_received(:publish)
      end

      it 'does not change the post status' do
        expect {
          described_class.perform_now(post)
        }.not_to change { post.reload.status }
      end
    end

    context 'when publishing fails' do
      before do
        allow(publisher_double).to receive(:publish).and_return(false)
        allow(post).to receive(:mark_as_failed!)
      end

      it 'marks the post as failed' do
        described_class.perform_now(post)
        expect(post).to have_received(:mark_as_failed!)
      end
    end

    context 'when an exception occurs' do
      let(:error_message) { 'Network error' }

      before do
        allow(publisher_double).to receive(:publish).and_raise(StandardError.new(error_message))
        allow(post).to receive(:mark_as_failed!)
        allow(Rails.logger).to receive(:error)
      end

      it 'marks the post as failed' do
        described_class.perform_now(post)
        expect(post).to have_received(:mark_as_failed!)
      end

      it 'logs the error' do
        described_class.perform_now(post)
        expect(Rails.logger).to have_received(:error).with(
          "Failed to publish post #{post.id} to Bluesky: #{error_message}"
        )
      end
    end

    context 'job queuing' do
      it 'queues the job' do
        expect {
          described_class.perform_later(post)
        }.to enqueue_job(described_class).with(post)
      end

      it 'performs the job asynchronously' do
        allow(BlueskyPublisher).to receive(:new).and_return(publisher_double)
        allow(publisher_double).to receive(:publish).and_return(true)

        perform_enqueued_jobs do
          described_class.perform_later(post)
        end

        expect(BlueskyPublisher).to have_received(:new).with(post)
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
