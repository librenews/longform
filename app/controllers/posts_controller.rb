class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :archive, :unarchive]
  
  # Use editor layout for new and edit actions
  layout 'editor', only: [:new, :edit]
  
  def index
    @posts = current_user.posts
                         .includes(:rich_text_content)
                         .recent
    
    # Apply filters
    @posts = @posts.by_status(params[:status]) if params[:status].present?
    @posts = @posts.search(params[:search]) if params[:search].present?
    
    # Paginate
    @posts = @posts.page(params[:page]).per(10)
    
    # For filters
    @status_counts = {
      all: current_user.posts.count,
      draft: current_user.posts.draft.count,
      published: current_user.posts.published.count,
      archived: current_user.posts.archived.count
    }
  end
  
  def show
    # Display individual post
  end
  
  def new
    @post = current_user.posts.build
  end
  
  def create
    @post = current_user.posts.build(post_params)
    
    if @post.save
      # Check if publish button was clicked
      if params[:publish] == "Publish"
        if @post.publish!
          respond_to do |format|
            format.html { redirect_to @post, notice: 'Post published to Bluesky!' }
            format.json { render json: { status: 'success', redirect_url: post_path(@post) } }
          end
        else
          respond_to do |format|
            format.html { redirect_to @post, alert: 'Post created but failed to publish. You can try publishing again from the post page.' }
            format.json { render json: { status: 'error', message: 'Failed to publish' } }
          end
        end
      else
        respond_to do |format|
          format.html { redirect_to edit_post_path(@post), notice: 'Post created successfully.' }
          format.json { render json: { status: 'success', redirect_url: edit_post_path(@post) } }
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @post.errors } }
      end
    end
  end
  
  def edit
    # Edit post form
  end
  
  def update
    if @post.update(post_params)
      respond_to do |format|
        format.html { redirect_to @post, notice: 'Post was successfully updated.' }
        format.json { render json: { status: 'success' } }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @post.errors } }
      end
    end
  end
  
  def destroy
    @post.destroy
    redirect_to posts_path, notice: 'Post was successfully deleted.'
  end
  
  def publish
    if @post.publish!
      redirect_to @post, notice: 'Post published to Bluesky!'
    else
      redirect_to @post, alert: 'Failed to publish post. Please try again.'
    end
  end
  
  def unpublish
    if @post.unpublish!
      redirect_to @post, notice: 'Post unpublished and moved to drafts.'
    else
      redirect_to @post, alert: 'Failed to unpublish post.'
    end
  end
  
  def archive
    if @post.archive!
      redirect_to @post, notice: 'Post archived successfully.'
    else
      redirect_to @post, alert: 'Failed to archive post.'
    end
  end
  
  def unarchive
    if @post.unarchive!
      redirect_to @post, notice: 'Post unarchived and moved to drafts.'
    else
      redirect_to @post, alert: 'Failed to unarchive post.'
    end
  end
  
  private
  
  def set_post
    @post = current_user.posts.find(params[:id])
  end
  
  def post_params
    params.require(:post).permit(:title, :content)
  end
end
