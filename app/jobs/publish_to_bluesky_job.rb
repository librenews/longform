class PublishToBlueskyJob < ApplicationJob
  queue_as :default
  
  def perform(post)
    return unless post.published?
    return unless post.user.has_valid_bluesky_token?
    
    begin
      publisher = BlueskyDpopPublisher.new(post.user)
      post_url = Rails.application.routes.url_helpers.post_url(post, host: ENV['APP_HOST'])
      result = publisher.publish(post.title, post.content.to_s, post_url)
      
      if result[:success]
        post.update!(
          bluesky_uri: result[:uri],
          bluesky_cid: result[:cid]
        )
        
        Rails.logger.info "Successfully published post #{post.id} to Bluesky via DPoP: #{result[:uri]}"
      else
        post.update!(status: :failed)
        Rails.logger.error "Failed to publish post #{post.id} via DPoP: #{result[:error]}"
      end
      
    rescue => e
      post.update!(status: :failed)
      Rails.logger.error "Error publishing post #{post.id} via DPoP: #{e.message}"
      raise e
    end
  end
end
