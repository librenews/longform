class Post < ApplicationRecord
  belongs_to :user
  has_rich_text :content
  
  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true
  
  enum :status, { 
    draft: 0, 
    published: 1, 
    archived: 2,
    failed: 3
  }, default: :draft
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :search, ->(query) { 
    return all if query.blank?
    where("title ILIKE ? OR excerpt ILIKE ?", "%#{query}%", "%#{query}%") 
  }
  
  before_save :generate_excerpt
  
  def published?
    published_at.present? && status == 'published'
  end
  
  def draft?
    status == 'draft'
  end
  
  def can_publish?
    (draft? || failed?) && content.present? && title.present?
  end
  
  def word_count
    content.to_plain_text.split.length
  end
  
  def reading_time_minutes
    (word_count / 200.0).ceil
  end
  
  def publish!
    return false unless can_publish?
    
    transaction do
      update!(
        status: :published,
        published_at: Time.current
      )
      
      PublishToBlueskyJob.perform_later(self)
    end
    
    true
  rescue => e
    update(status: :failed)
    Rails.logger.error "Failed to publish post #{id}: #{e.message}"
    false
  end
  
  def unpublish!
    return false unless published?
    
    # Delete from Bluesky if it was published there
    if bluesky_uri.present?
      begin
        publisher = BlueskyDpopPublisher.new(user)
        publisher.delete_record(bluesky_uri)
        Rails.logger.info "Successfully deleted Bluesky record for post #{id}: #{bluesky_uri}"
      rescue => e
        Rails.logger.error "Failed to delete Bluesky record for post #{id}: #{e.message}"
        # Continue with unpublishing even if Bluesky deletion fails
      end
    end
    
    update!(
      status: :draft,
      published_at: nil,
      bluesky_uri: nil,
      bluesky_cid: nil
    )
  end
  
  def archive!
    return false if archived?
    
    update!(status: :archived)
  end
  
  def unarchive!
    return false unless archived?
    
    update!(status: :draft)
  end
  
  def bluesky_url
    return nil unless bluesky_uri
    
    # Convert AT Protocol URI to web URL
    # at://did:plc:xxx/app.bsky.feed.post/xxx -> https://bsky.app/profile/handle/post/xxx
    if bluesky_uri.match(/at:\/\/(.+)\/app\.bsky\.feed\.post\/(.+)/)
      did = $1
      post_id = $2
      "https://bsky.app/profile/#{user.handle}/post/#{post_id}"
    end
  end
  
  private
  
  def generate_excerpt
    return unless content.present?
    
    plain_text = content.to_plain_text
    self.excerpt = plain_text.truncate(300, separator: ' ')
  end
end
