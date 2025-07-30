# Development Guide

This guide covers local development setup, contributing guidelines, and the technical architecture of Longform.

## Local Development Setup

### Prerequisites

- Ruby 3.2.0+
- Node.js 18+
- PostgreSQL 14+
- Git

### Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/longform.git
cd longform

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
npm install

# Set up environment variables
cp .env.example .env.development
# Edit .env.development with your local settings

# Create and migrate database
rails db:create db:migrate

# Seed sample data (optional)
rails db:seed

# Start the development server
bin/dev
```

The application will be available at:
- Tunnel setup: `https://dev.libre.news` (server on port 3001)
- Localhost only: `http://localhost:3001`

### Environment Configuration

Create `.env.development`:

```env
RAILS_ENV=development
DATABASE_URL=postgresql://localhost/longform_development

# Tunnel setup (recommended)
APP_HOST=dev.libre.news
APP_URL=https://dev.libre.news
BLUESKY_CLIENT_ID=your_dev_client_id
BLUESKY_CLIENT_SECRET=your_dev_client_secret
BLUESKY_REDIRECT_URI=https://dev.libre.news/auth/atproto/callback

# Alternative localhost setup:
# APP_HOST=localhost:3001
# APP_URL=http://localhost:3001
# BLUESKY_REDIRECT_URI=http://localhost:3001/auth/atproto/callback

RAILS_LOG_LEVEL=debug
```

### Development Tools

#### Code Quality

```bash
# Run RuboCop for Ruby style checking
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Run Brakeman for security analysis
bundle exec brakeman

# Generate documentation
bundle exec yard doc
```

#### Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec

# View coverage report
open coverage/index.html
```

#### Database

```bash
# Reset database
rails db:reset

# Run migrations
rails db:migrate

# Rollback migration
rails db:rollback

# Check migration status
rails db:migrate:status

# Generate migration
rails generate migration AddPublishedAtToPosts published_at:datetime
```

## Architecture Overview

### Application Structure

```
app/
├── controllers/          # HTTP request handling
│   ├── application_controller.rb
│   ├── posts_controller.rb
│   ├── sessions_controller.rb
│   └── users_controller.rb
├── models/              # Business logic and data models
│   ├── application_record.rb
│   ├── post.rb
│   └── user.rb
├── services/            # Business logic services
│   ├── bluesky/
│   │   ├── auth_service.rb
│   │   ├── api_client.rb
│   │   └── post_publisher.rb
│   └── post_service.rb
├── jobs/                # Background jobs
│   ├── application_job.rb
│   └── publish_post_job.rb
├── views/               # HTML templates
│   ├── layouts/
│   ├── posts/
│   └── users/
├── assets/              # CSS, JS, images
│   ├── stylesheets/
│   ├── javascript/
│   └── images/
└── lib/                 # Custom libraries
    └── bluesky/
        └── at_protocol.rb
```

### Key Components

#### Models

**User Model:**
```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  
  validates :bluesky_handle, presence: true, uniqueness: true
  validates :bluesky_did, presence: true, uniqueness: true
  
  def display_name
    name.presence || bluesky_handle
  end
end
```

**Post Model:**
```ruby
# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user
  has_rich_text :content
  
  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true
  
  scope :published, -> { where.not(published_at: nil) }
  scope :drafts, -> { where(published_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  
  def published?
    published_at.present?
  end
  
  def publish!
    update!(published_at: Time.current)
    PublishPostJob.perform_later(self)
  end
end
```

#### Services

**Bluesky API Client:**
```ruby
# app/services/bluesky/api_client.rb
class Bluesky::ApiClient
  include HTTParty
  base_uri 'https://bsky.social/xrpc'
  
  def initialize(access_token)
    @access_token = access_token
    @options = {
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      }
    }
  end
  
  def create_post(text, **options)
    body = {
      repo: current_user_did,
      collection: 'app.bsky.feed.post',
      record: {
        text: text,
        createdAt: Time.current.iso8601,
        **options
      }
    }
    
    post('/com.atproto.repo.createRecord', body: body.to_json, **@options)
  end
  
  private
  
  def current_user_did
    # Implementation to get user's DID
  end
end
```

**Post Publisher Service:**
```ruby
# app/services/bluesky/post_publisher.rb
class Bluesky::PostPublisher
  def initialize(post)
    @post = post
    @user = post.user
  end
  
  def publish
    client = Bluesky::ApiClient.new(@user.access_token)
    
    response = client.create_post(
      formatted_content,
      facets: extract_facets,
      embed: build_embed
    )
    
    if response.success?
      @post.update!(
        bluesky_uri: response['uri'],
        bluesky_cid: response['cid']
      )
    else
      raise PublishError, response['error']
    end
  end
  
  private
  
  def formatted_content
    # Convert rich text to AT Protocol format
  end
  
  def extract_facets
    # Extract links, mentions, hashtags
  end
  
  def build_embed
    # Build embed for images, links, etc.
  end
end
```

#### Controllers

**Posts Controller:**
```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :edit, :update, :destroy, :publish]
  
  def index
    @posts = current_user.posts
                         .includes(:rich_text_content)
                         .page(params[:page])
                         .per(10)
    
    @posts = @posts.where("title ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @posts = filter_by_status(@posts, params[:status])
  end
  
  def show
    # Implementation
  end
  
  def new
    @post = current_user.posts.build
  end
  
  def create
    @post = current_user.posts.build(post_params)
    
    if @post.save
      redirect_to @post, notice: 'Post was successfully created.'
    else
      render :new
    end
  end
  
  def publish
    if @post.publish!
      redirect_to @post, notice: 'Post published to Bluesky!'
    else
      redirect_to @post, alert: 'Failed to publish post.'
    end
  end
  
  private
  
  def set_post
    @post = current_user.posts.find(params[:id])
  end
  
  def post_params
    params.require(:post).permit(:title, :content)
  end
  
  def filter_by_status(posts, status)
    case status
    when 'published'
      posts.published
    when 'drafts'
      posts.drafts
    else
      posts
    end
  end
end
```

### Database Schema

```ruby
# db/migrate/001_create_users.rb
class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :bluesky_handle, null: false
      t.string :bluesky_did, null: false
      t.string :name
      t.string :avatar_url
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      
      t.timestamps
      
      t.index :bluesky_handle, unique: true
      t.index :bluesky_did, unique: true
    end
  end
end

# db/migrate/002_create_posts.rb
class CreatePosts < ActiveRecord::Migration[7.2]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.datetime :published_at
      t.string :bluesky_uri
      t.string :bluesky_cid
      t.text :excerpt
      
      t.timestamps
      
      t.index [:user_id, :created_at]
      t.index [:user_id, :published_at]
      t.index :bluesky_uri, unique: true, where: "bluesky_uri IS NOT NULL"
    end
  end
end
```

### Frontend Architecture

#### Stimulus Controllers

```javascript
// app/javascript/controllers/editor_controller.js
import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"

export default class extends Controller {
  static targets = ["editor", "content"]
  
  connect() {
    this.editor = new Editor({
      element: this.editorTarget,
      extensions: [StarterKit],
      content: this.contentTarget.value,
      onUpdate: ({ editor }) => {
        this.contentTarget.value = editor.getHTML()
        this.autosave()
      }
    })
  }
  
  disconnect() {
    this.editor?.destroy()
  }
  
  autosave() {
    clearTimeout(this.autosaveTimeout)
    this.autosaveTimeout = setTimeout(() => {
      this.save()
    }, 2000)
  }
  
  save() {
    const formData = new FormData()
    formData.append('post[title]', this.titleTarget.value)
    formData.append('post[content]', this.contentTarget.value)
    
    fetch(this.data.get("url"), {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
  }
}
```

#### Styling Architecture

```scss
// app/assets/stylesheets/application.scss
@import "bootstrap";

// Component-based structure
@import "components/editor";
@import "components/post-card";
@import "components/navigation";

// Utilities
@import "utilities/spacing";
@import "utilities/typography";

// Variables
:root {
  --primary-color: #1da1f2;
  --secondary-color: #14171a;
  --text-color: #657786;
  --background-color: #f5f8fa;
  --border-color: #e1e8ed;
}
```

## Testing Strategy

### Test Structure

```
spec/
├── controllers/         # Controller tests
├── models/             # Model tests
├── services/           # Service tests
├── jobs/              # Job tests
├── requests/          # Integration tests
├── system/            # End-to-end tests
├── factories/         # Test data factories
└── support/           # Test helpers
```

### Testing Guidelines

#### Unit Tests

```ruby
# spec/models/post_spec.rb
RSpec.describe Post, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }
    it { should validate_length_of(:title).is_at_most(200) }
  end
  
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_rich_text(:content) }
  end
  
  describe 'scopes' do
    let!(:published_post) { create(:post, :published) }
    let!(:draft_post) { create(:post, :draft) }
    
    it 'returns published posts' do
      expect(Post.published).to contain_exactly(published_post)
    end
    
    it 'returns draft posts' do
      expect(Post.drafts).to contain_exactly(draft_post)
    end
  end
  
  describe '#publish!' do
    let(:post) { create(:post, :draft) }
    
    it 'sets published_at timestamp' do
      expect { post.publish! }.to change(post, :published_at).from(nil)
    end
    
    it 'enqueues publish job' do
      expect { post.publish! }.to have_enqueued_job(PublishPostJob)
    end
  end
end
```

#### Service Tests

```ruby
# spec/services/bluesky/post_publisher_spec.rb
RSpec.describe Bluesky::PostPublisher do
  let(:user) { create(:user, :with_valid_token) }
  let(:post) { create(:post, user: user) }
  let(:publisher) { described_class.new(post) }
  
  describe '#publish' do
    context 'when API call succeeds' do
      before do
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord")
          .to_return(
            status: 200,
            body: { uri: 'at://did:example/app.bsky.feed.post/123', cid: 'bafyabc123' }.to_json
          )
      end
      
      it 'updates post with Bluesky URI and CID' do
        publisher.publish
        
        expect(post.reload).to have_attributes(
          bluesky_uri: 'at://did:example/app.bsky.feed.post/123',
          bluesky_cid: 'bafyabc123'
        )
      end
    end
    
    context 'when API call fails' do
      before do
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord")
          .to_return(status: 400, body: { error: 'Invalid request' }.to_json)
      end
      
      it 'raises PublishError' do
        expect { publisher.publish }.to raise_error(Bluesky::PostPublisher::PublishError)
      end
    end
  end
end
```

#### System Tests

```ruby
# spec/system/post_creation_spec.rb
RSpec.describe "Post creation", type: :system do
  let(:user) { create(:user) }
  
  before do
    sign_in_as(user)
  end
  
  it 'allows user to create and publish a post' do
    visit new_post_path
    
    fill_in 'Title', with: 'My First Longform Post'
    
    # Use the rich text editor
    within('.trix-editor') do
      type 'This is the content of my first longform post on Bluesky!'
    end
    
    click_button 'Save Draft'
    
    expect(page).to have_content('Post was successfully created.')
    expect(page).to have_content('My First Longform Post')
    
    click_button 'Publish to Bluesky'
    
    expect(page).to have_content('Post published to Bluesky!')
  end
end
```

### Test Data Factories

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    bluesky_handle { "user#{SecureRandom.hex(4)}.bsky.social" }
    bluesky_did { "did:plc:#{SecureRandom.hex(12)}" }
    name { Faker::Name.name }
    avatar_url { Faker::Internet.url }
    
    trait :with_valid_token do
      access_token { SecureRandom.hex(32) }
      refresh_token { SecureRandom.hex(32) }
      token_expires_at { 1.hour.from_now }
    end
  end
end

# spec/factories/posts.rb
FactoryBot.define do
  factory :post do
    user
    title { Faker::Lorem.sentence }
    content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    
    trait :published do
      published_at { 1.hour.ago }
      bluesky_uri { "at://#{user.bluesky_did}/app.bsky.feed.post/#{SecureRandom.hex(8)}" }
      bluesky_cid { "bafy#{SecureRandom.hex(16)}" }
    end
    
    trait :draft do
      published_at { nil }
    end
  end
end
```

## Contributing Guidelines

### Getting Started

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-new-feature`
3. Make your changes with tests
4. Run the test suite: `bundle exec rspec`
5. Run style checks: `bundle exec rubocop`
6. Commit your changes: `git commit -am 'Add some feature'`
7. Push to the branch: `git push origin feature/my-new-feature`
8. Submit a pull request

### Code Style

We follow the Ruby Style Guide and Rails conventions:

- Use 2 spaces for indentation
- Keep lines under 100 characters
- Use descriptive variable and method names
- Write clear commit messages
- Add tests for all new functionality

### Pull Request Guidelines

- Include a clear description of the changes
- Reference any related issues
- Ensure all tests pass
- Include screenshots for UI changes
- Update documentation if needed

### Development Workflow

```bash
# Start development environment
bin/dev

# Run tests continuously
bundle exec guard

# Check code style
bundle exec rubocop

# Run security scan
bundle exec brakeman

# Generate documentation
bundle exec yard doc
```

## Debugging

### Common Issues

**OAuth Issues:**
```bash
# Check OAuth configuration
rails console
> Rails.application.credentials.bluesky
> ENV['BLUESKY_REDIRECT_URI']
```

**Database Issues:**
```bash
# Reset database
rails db:reset

# Check database connections
rails db:pool:status
```

**Asset Issues:**
```bash
# Clear asset cache
rails assets:clobber

# Recompile assets
rails assets:precompile
```

### Debugging Tools

**Byebug for Ruby:**
```ruby
def some_method
  byebug # Debugger will stop here
  # Your code
end
```

**Browser Developer Tools:**
- Use console for JavaScript debugging
- Network tab for API request inspection
- Application tab for storage inspection

**Rails Console:**
```bash
# Start console
rails console

# Test models and services
user = User.first
post = user.posts.create!(title: "Test", content: "Content")
Bluesky::PostPublisher.new(post).publish
```

## Performance Monitoring

### Development Profiling

```ruby
# Add to Gemfile (development group)
gem 'rack-mini-profiler'
gem 'memory_profiler'
gem 'flamegraph'
gem 'stackprof'

# Profile specific actions
def slow_action
  Rack::MiniProfiler.step("Database queries") do
    # Your database code
  end
  
  Rack::MiniProfiler.step("API calls") do
    # Your API code
  end
end
```

### Database Query Analysis

```ruby
# In Rails console
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Analyze slow queries
Post.includes(:user, :rich_text_content).limit(10)
```

---

Happy coding! 🚀
