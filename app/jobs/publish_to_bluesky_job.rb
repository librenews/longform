class PublishToBlueskyJob < ApplicationJob
  queue_as :default
  
  def perform(post)
    return unless post.published? && post.user.valid_token?
    
    begin
      publisher = BlueskyPublisher.new(post)
      result = publisher.publish
      
      if result[:success]
        post.update!(
          bluesky_uri: result[:uri],
          bluesky_cid: result[:cid],
          bluesky_metadata: result[:metadata]
        )
        
        Rails.logger.info "Successfully published post #{post.id} to Bluesky"
      else
        post.update!(status: :failed)
        Rails.logger.error "Failed to publish post #{post.id}: #{result[:error]}"
      end
      
    rescue => e
      post.update!(status: :failed)
      Rails.logger.error "Error publishing post #{post.id}: #{e.message}"
      raise e
    end
  end
end
