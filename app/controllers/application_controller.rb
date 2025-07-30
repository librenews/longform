class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :authenticate_user!
  helper_method :current_user, :user_signed_in?
  
  skip_before_action :authenticate_user!, only: [:health]
  
  def health
    render json: { 
      status: 'ok', 
      timestamp: Time.current.iso8601,
      version: Rails.application.version || '1.0.0'
    }
  end
  
  private
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  
  def user_signed_in?
    current_user.present?
  end
  
  def authenticate_user!
    redirect_to root_path unless user_signed_in?
  end
  
  def require_no_authentication
    redirect_to dashboard_path if user_signed_in?
  end
end
