require 'net/http'
require 'json'

class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  
  validates :handle, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :uid, presence: true

  
  validates :uid, uniqueness: { scope: :provider }
  
  before_save :set_display_name_from_handle
  
  # OAuth token management
  def token_expired?
    token_expires_at.present? && token_expires_at < Time.current
  end
  
  def valid_token?
    access_token.present? && !token_expired?
  end
  
  # Alias for consistency (some code might use expires_at)
  def expires_at
    token_expires_at
  end
  
  def tokens_valid?
    valid_token?
  end
  
  # Clear expired or invalid tokens
  def clear_bluesky_tokens!
    update!(
      access_token: nil,
      refresh_token: nil,
      token_expires_at: nil
    )
  end

  # DPoP key management for Bluesky OAuth
  def dpop_private_key
    # For now, reuse the same key pair as OmniAuth
    # In production, you might want separate DPoP keys per user
    OmniAuth::Atproto::KeyManager.current_private_key
  end

  def dpop_jwk
    # Public key in JWK format for DPoP headers
    OmniAuth::Atproto::KeyManager.current_jwk
  end

  # Check if user has valid Bluesky authentication
  def has_valid_bluesky_token?
    provider == 'atproto' && access_token.present? && !token_expired?
  end
  
  # Scopes for posts
  def published_posts
    posts.published
  end
  
  def draft_posts
    posts.drafts
  end
  
  # Stats
  def posts_count
    posts.count
  end
  
  def published_posts_count
    published_posts.count
  end
  
  def draft_posts_count
    draft_posts.count
  end
  
  def total_word_count
    posts.sum(&:word_count)
  end
  
  # Create user from OAuth data
  def self.from_omniauth(auth_hash)
    # AT Protocol uses DID as the unique identifier
    uid = auth_hash.info['did'] || auth_hash.uid
    
    where(provider: auth_hash.provider, uid: uid).first_or_create! do |user|
      user.uid = uid
      user.handle = Thread.current[:session]&.dig('pending_handle') || auth_hash.info['handle'] || "user"
      user.email = auth_hash.info['email'] || "#{user.handle}@placeholder.com"
      user.display_name = auth_hash.info['name'] || user.handle
      
      # Try multiple possible locations for avatar
      user.avatar_url = auth_hash.info['image'] || 
                       auth_hash.info['avatar'] || 
                       auth_hash.info['picture'] ||
                       auth_hash.extra&.dig('raw_info', 'avatar') ||
                       auth_hash.extra&.dig('raw_info', 'picture') ||
                       auth_hash.extra&.dig('raw_info', 'image')
      
      user.access_token = auth_hash.credentials['token']
      user.refresh_token = auth_hash.credentials['refresh_token']
      
      if auth_hash.credentials['expires_at'].is_a?(Time)
        user.token_expires_at = auth_hash.credentials['expires_at']
      elsif auth_hash.credentials['expires_at']
        user.token_expires_at = Time.at(auth_hash.credentials['expires_at'])
      end
    end
  end

  # Update user from OAuth data on subsequent logins
  def update_from_omniauth!(auth_hash)
    attributes_to_update = {
      display_name: auth_hash.info['name'] || self.handle,
      avatar_url: auth_hash.info['image'] || 
                 auth_hash.info['avatar'] || 
                 auth_hash.info['picture'] ||
                 auth_hash.extra&.dig('raw_info', 'avatar') ||
                 auth_hash.extra&.dig('raw_info', 'picture') ||
                 auth_hash.extra&.dig('raw_info', 'image'),
      access_token: auth_hash.credentials['token'],
      refresh_token: auth_hash.credentials['refresh_token']
    }
    
    if auth_hash.credentials['expires_at'].is_a?(Time)
      attributes_to_update[:token_expires_at] = auth_hash.credentials['expires_at']
    elsif auth_hash.credentials['expires_at']
      attributes_to_update[:token_expires_at] = Time.at(auth_hash.credentials['expires_at'])
    end
    
    update!(attributes_to_update)
  end

  # Avatar helper methods
  def avatar_url_or_default
    avatar_url.presence || fetch_bluesky_avatar || default_avatar_url
  end

  def fetch_bluesky_avatar
    return nil unless handle.present?
    
    begin
      # Use the AT Protocol API to fetch profile info
      uri = URI("https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile")
      uri.query = URI.encode_www_form(actor: handle)
      
      response = Net::HTTP.get_response(uri)
      if response.code == '200'
        profile_data = JSON.parse(response.body)
        avatar_url = profile_data.dig('avatar')
        
        # Update our stored avatar_url if we found one
        if avatar_url.present? && self.avatar_url != avatar_url
          update_column(:avatar_url, avatar_url)
        end
        
        avatar_url
      end
    rescue => e
      Rails.logger.error "Failed to fetch Bluesky avatar for #{handle}: #{e.message}"
      nil
    end
  end

  def default_avatar_url
    # Generate a simple default avatar URL (could be a gravatar, identicon, or static image)
    "https://ui-avatars.com/api/?name=#{CGI.escape(display_name || handle)}&background=random&size=128"
  end
  
  private
  
  def set_display_name_from_handle
    self.display_name = handle if display_name.blank?
  end
end
