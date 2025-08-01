source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.2", ">= 7.2.2.1"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Dart SASS [https://github.com/rails/dartsass-rails]
gem "dartsass-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Authentication and OAuth
gem "omniauth"
gem "omniauth-rails_csrf_protection"
gem "omniauth-atproto"

# HTTP client for Bluesky API
# HTTP clients for API requests
gem "faraday"
gem "faraday-retry"

# JWT for DPoP token generation
gem "jwt"

# HTML to Markdown conversion for blog entries
gem "reverse_markdown"

# Pagination
gem "kaminari"

# Rich text editor
gem "trix-rails"

# Image processing for Action Text
gem "image_processing", "~> 1.2"

# Configuration management for self-hosting
gem "dotenv-rails"
gem "config"

# Health checks for deployments
gem "health_check"

# Docker and deployment helpers
gem "foreman"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ], require: "debug/prelude"

  # Testing framework
  gem "rspec-rails"
  
  # Test factories
  gem "factory_bot_rails"
  
  # Fake data generation
  gem "faker"
  
  # Code coverage
  gem "simplecov", require: false
  gem "simplecov-html", require: false
  
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :test do
  # System testing
  gem "capybara"
  gem "selenium-webdriver"
  
  # Database cleaner
  gem "database_cleaner-active_record"
  
  # HTTP request stubbing
  gem "webmock"
  gem "vcr"
  
  # Time manipulation for tests
  gem "timecop"
  
  # Additional matchers and helpers
  gem "shoulda-matchers"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Highlight the fine-grained location where an error occurred [https://github.com/ruby/error_highlight]
  gem "error_highlight", ">= 0.4.0", platforms: [ :ruby ]
  
  # Documentation generation
  gem "yard"
  gem "redcarpet" # For markdown in YARD docs
  
  # API documentation
  gem "rswag"
  gem "rswag-ui"
end

