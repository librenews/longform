module TokenValidation
  extend ActiveSupport::Concern

  included do
    before_action :validate_active_token, if: :user_signed_in?
    rescue_from TokenExpiredError, with: :handle_expired_token
  end

  class TokenExpiredError < StandardError; end

  private

  def validate_active_token
    return unless current_user&.access_token.present?
    
    # Skip validation for certain safe actions
    return if skip_token_validation?
    
    # Check if token is expired by timestamp first
    if current_user.token_expired?
      Rails.logger.info "Token expired for user #{current_user.id}, attempting refresh"
      handle_token_expiration
      return
    end
    
    # For critical actions, verify token with AT Protocol
    if critical_action?
      verify_token_with_api
    end
  end

  def verify_token_with_api
    return true unless current_user&.access_token.present?
    
    begin
      # Use a lightweight AT Protocol endpoint to verify token
      response = Faraday.get("#{current_user.pds_endpoint}/xrpc/com.atproto.server.getSession") do |req|
        req.headers['Authorization'] = "Bearer #{current_user.access_token}"
      end
      
      if response.status == 401
        Rails.logger.warn "API token validation failed for user #{current_user.id}"
        raise TokenExpiredError, "Token validation failed"
      end
      
      # Update last validated timestamp if successful
      current_user.update_column(:last_token_validation, Time.current) if response.success?
      
      response.success?
    rescue Faraday::Error => e
      Rails.logger.error "Token validation network error: #{e.message}"
      # Don't force logout on network errors, just log
      false
    end
  end

  def handle_token_expiration
    if current_user.refresh_token.present?
      refresh_result = refresh_user_token
      if refresh_result[:success]
        Rails.logger.info "Successfully refreshed token for user #{current_user.id}"
        return
      else
        Rails.logger.warn "Token refresh failed for user #{current_user.id}: #{refresh_result[:error]}"
      end
    end
    
    # If refresh failed or no refresh token, handle as expired
    raise TokenExpiredError, "Token expired and refresh failed"
  end

  def handle_expired_token
    preserve_form_data if request.post? || request.patch? || request.put?
    
    # Clear the session but keep user record
    current_user.clear_bluesky_tokens!
    session[:user_id] = nil
    
    # Store return path for after re-authentication
    session[:return_to] = request.fullpath unless skip_return_path?
    
    respond_to do |format|
      format.html do
        flash[:alert] = "Your session has expired. Please sign in again to continue."
        redirect_to root_path
      end
      format.json do
        render json: { 
          error: "Session expired", 
          redirect_url: root_path,
          preserved_data: session[:preserved_form_data].present?
        }, status: :unauthorized
      end
    end
  end

  def preserve_form_data
    # Only preserve certain safe form data
    return unless should_preserve_form_data?
    
    # Extract form data safely
    form_data = {}
    
    if params[:post].present?
      form_data[:post] = params[:post].permit(:title, :content, :status, :excerpt)
    elsif params[:comment].present?
      form_data[:comment] = params[:comment].permit(:content)
    end
    
    if form_data.any?
      session[:preserved_form_data] = {
        controller: params[:controller],
        action: params[:action],
        data: form_data,
        timestamp: Time.current.to_i
      }
      
      flash[:notice] = "We've saved your changes. Please sign in to continue."
    end
  end

  def restore_form_data
    preserved = session.delete(:preserved_form_data)
    return nil unless preserved
    
    # Check if data is not too old (5 minutes max)
    return nil if preserved[:timestamp] < 5.minutes.ago.to_i
    
    preserved[:data]
  end

  def refresh_user_token
    return { success: false, error: "No refresh token available" } unless current_user.refresh_token.present?
    
    begin
      # Use AT Protocol token refresh endpoint
      response = Faraday.post("#{current_user.pds_endpoint}/xrpc/com.atproto.server.refreshSession") do |req|
        req.headers['Authorization'] = "Bearer #{current_user.refresh_token}"
        req.headers['Content-Type'] = 'application/json'
      end
      
      if response.success?
        token_data = JSON.parse(response.body)
        
        current_user.update!(
          access_token: token_data['accessJwt'],
          refresh_token: token_data['refreshJwt'],
          token_expires_at: token_data['expires_at'] ? Time.parse(token_data['expires_at']) : 1.hour.from_now
        )
        
        { success: true }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || 'Token refresh failed' }
      end
    rescue => e
      Rails.logger.error "Token refresh error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def critical_action?
    # Define which actions require real-time token validation
    return true if params[:action] == 'publish'
    return true if params[:action] == 'create' && params[:controller] == 'posts'
    return true if params[:action] == 'update' && params[:controller] == 'posts'
    return true if request.post? && params[:controller] == 'records'
    
    false
  end

  def skip_token_validation?
    # Skip validation for safe, read-only actions
    return true if params[:action] == 'index' && request.get?
    return true if params[:action] == 'show' && request.get?
    return true if params[:controller] == 'sessions'
    return true if params[:controller] == 'oauth'
    
    false
  end

  def should_preserve_form_data?
    # Only preserve data for specific forms
    return true if params[:controller] == 'posts' && %w[create update].include?(params[:action])
    return true if params[:controller] == 'comments' && params[:action] == 'create'
    
    false
  end

  def skip_return_path?
    # Don't store return path for certain actions
    return true if params[:controller] == 'sessions'
    return true if params[:controller] == 'oauth'
    return true if request.xhr? # AJAX requests
    
    false
  end
end
