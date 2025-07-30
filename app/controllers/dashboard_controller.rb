class DashboardController < ApplicationController
  def index
    @posts = current_user.posts.includes(:rich_text_content).order(updated_at: :desc)
    @draft_posts = @posts.draft
    @published_posts = @posts.published
    @recent_posts = @posts.limit(5)
    
    # Stats for the dashboard
    @draft_count = @draft_posts.count
    @published_count = @published_posts.count
    @total_posts = @posts.count
    @total_word_count = current_user.total_word_count
  end
end