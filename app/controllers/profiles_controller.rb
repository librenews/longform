class ProfilesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
  
  before_action :find_user_by_handle, only: [:show]
  
  def show
    if @user
      fetcher = BlueskyPostFetcher.new(@user)
      @latest_posts = fetcher.fetch_latest_posts(limit: 10)
      @total_posts_count = @latest_posts.count # For now, just show what we fetched
    else
      redirect_to root_path, alert: "User not found"
    end
  end
  
  private
  
  def find_user_by_handle
    @user = User.find_by(handle: params[:handle])
  end
end
