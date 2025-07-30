class SessionsController < ApplicationController
  skip_before_action :authenticate_user!
  
  def new
    redirect_to dashboard_path if user_signed_in?
  end
  
  def omniauth
    auth_hash = request.env['omniauth.auth']
    
    # Handle case where auth_hash might be nil (direct form submission)
    unless auth_hash
      redirect_to root_path, alert: 'Authentication failed. Please try again.'
      return
    end
    
    # Store session for User model to access
    Thread.current[:session] = session
    
    # AT Protocol uses DID as the unique identifier
    uid = auth_hash.info['did'] || auth_hash.uid
    user = User.find_by(uid: uid, provider: auth_hash.provider)
    
    if user
      # Update existing user with fresh auth data
      user.update_from_omniauth!(auth_hash)
    else
      # Create new user
      user = User.from_omniauth(auth_hash)
    end
    
    # Clean up session
    session.delete('pending_handle')
    Thread.current[:session] = nil
    
    if user&.persisted?
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: 'Successfully signed in with Bluesky!'
    else
      redirect_to root_path, alert: 'There was an error signing you in. Please try again.'
    end
  rescue => e
    Rails.logger.error "OAuth error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to root_path, alert: 'Authentication failed. Please try again.'
  end
  
  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: 'You have been signed out.'
  end
  
  def failure
    redirect_to root_path, alert: 'Authentication failed. Please try again.'
  end
end
