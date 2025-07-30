require 'simple_rails_helper'

RSpec.describe "Basic Application Setup", type: :model do
  context "Models" do
    it "can create a User" do
      user = User.new(
        handle: 'testuser',
        email: 'test@example.com',
        provider: 'bluesky',
        uid: 'test123',
        access_token: 'token123'
      )
      expect(user).to be_valid
    end

    it "can create a Post" do
      user = User.create!(
        handle: 'testuser',
        email: 'test@example.com',
        provider: 'bluesky',
        uid: 'test123',
        access_token: 'token123'
      )
      
      post = Post.new(
        title: 'Test Post',
        content: 'This is test content',
        user: user
      )
      expect(post).to be_valid
    end
  end

  context "Associations" do
    it "User has many posts" do
      user = User.create!(
        handle: 'testuser',
        email: 'test@example.com',
        provider: 'bluesky',
        uid: 'test123',
        access_token: 'token123'
      )
      
      post = user.posts.create!(
        title: 'Test Post',
        content: 'This is test content'
      )
      
      expect(user.posts).to include(post)
    end
  end
end
