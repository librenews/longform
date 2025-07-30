# Longform

A beautiful, minimalist blogging platform for creating and managing longform content with Bluesky integration.

## 🌟 Features

### Core Functionality
- **Rich Text Editor** - Write with Trix editor featuring auto-save functionality
- **Post Management** - Complete CRUD operations for your content
- **Status Management** - Draft, Published, Archived, and Failed states
- **Search & Filtering** - Find content quickly with status-based filtering and search
- **Word Count & Reading Time** - Automatic content analysis and metadata

### Content Organization
- **Draft System** - Save and iterate on unpublished content
- **Publishing Workflow** - Seamless draft-to-published transitions  
- **Archive System** - Hide posts without permanent deletion
- **Bulk Operations** - Manage multiple posts efficiently

### Authentication & Security
- **Bluesky OAuth Integration** - Secure authentication with AT Protocol
- **Avatar Fetching** - Automatic profile integration from Bluesky
- **Session Management** - Secure user sessions and data protection

### User Experience
- **Responsive Design** - Clean, mobile-friendly interface with PicoCSS
- **Real-time Feedback** - Instant save confirmations and status updates
- **Confirmation Dialogs** - Safe operations with user confirmation prompts
- **Semantic Styling** - Beautiful, accessible interface design

## 🚀 Quick Start

### Local Development

```bash
# Clone the repository
git clone https://github.com/yourusername/longform.git
cd longform

# Quick setup with guided configuration
./scripts/dev-setup.sh

# Or manual setup:
# Copy environment template
cp .env.development .env

# Edit .env with your settings (see Configuration section)
# nano .env

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Generate AT Protocol keys (required for OAuth)
rails atproto:generate_keys

# Start the development server on port 3001 (for tunnel)
rails server -p 3001

# Set up tunnel: dev.libre.news -> localhost:3001
# Your instance is now running at https://dev.libre.news
```

### Important: AT Protocol Keys

Each environment needs unique AT Protocol keys for OAuth. These are automatically generated during setup but can be manually created:

```bash
# Generate new keys
rails atproto:generate_keys

# Rotate existing keys (backs up old ones)
rails atproto:rotate_keys
```

**Security Note**: Keys are never committed to git and are unique per environment.

### Docker Setup

```bash
# Start with Docker Compose
docker-compose up -d

# Run database migrations
docker-compose exec app rails db:create db:migrate

# Your instance is now running at http://localhost:3000
```

## 🛠️ Technology Stack

- **Backend**: Ruby on Rails 7.2.2
- **Database**: PostgreSQL  
- **Frontend**: Turbo + Stimulus + PicoCSS
- **Rich Text**: Action Text with Trix editor
- **Authentication**: AT Protocol OAuth (Bluesky)
- **Deployment**: Docker-ready with Dockerfile and docker-compose.yml

## 📊 Post Status System

Longform uses a comprehensive status system for content management:

- **Draft** (0) - Unpublished content, work in progress
- **Published** (1) - Live content visible to readers
- **Archived** (2) - Hidden content, preserved but not visible
- **Failed** (3) - Posts that encountered publishing errors

## 🎯 Usage

1. **Sign In** - Authenticate with your Bluesky account
2. **Create** - Write new posts with the rich text editor
3. **Manage** - Use the posts dashboard to organize content
4. **Publish** - Transition drafts to published status
5. **Archive** - Hide posts without permanent deletion
6. **Search** - Find content using the built-in search and filters

## 🔧 Configuration

Essential environment variables for development and production:

```env
# Application Configuration (REQUIRED)
APP_HOST=yourdomain.com                    # Your domain/host (automatically added to allowed hosts)
APP_URL=https://yourdomain.com             # Full URL for OAuth callbacks
APP_NAME="Your Longform Instance"          # Instance name

# Optional: Additional allowed hosts (comma-separated)
ALLOWED_HOSTS=www.yourdomain.com,staging.yourdomain.com

# Database
DATABASE_URL=postgresql://user:password@localhost/longform_production

# Bluesky OAuth (get from https://bsky.social/settings/app-passwords)
BLUESKY_CLIENT_ID=your_client_id
BLUESKY_CLIENT_SECRET=your_client_secret
BLUESKY_REDIRECT_URI=https://yourdomain.com/auth/atproto/callback

# Rails
SECRET_KEY_BASE=your_secret_key
RAILS_ENV=production
```

### Development Environment

For local development, copy `.env.development` to `.env` and customize:

**Tunnel-based development (recommended):**
```env
APP_HOST=dev.libre.news                           # Automatically added to allowed hosts
APP_URL=https://dev.libre.news
BLUESKY_REDIRECT_URI=https://dev.libre.news/auth/atproto/callback
```

**Localhost-only development:**
```env
APP_HOST=localhost:3001                           # Automatically added to allowed hosts  
APP_URL=http://localhost:3001
BLUESKY_REDIRECT_URI=http://localhost:3001/auth/atproto/callback
```

**Additional hosts (optional):**
```env
ALLOWED_HOSTS=staging.domain.com,test.domain.com  # Comma-separated additional hosts
```

### Production Environment

Ensure all required environment variables are set, especially:
- `APP_URL` (required for OAuth callbacks)
- `APP_HOST` (automatically added to allowed hosts for request validation)
- Database and OAuth credentials

## 🧪 Testing

```bash
# Run the test suite
bundle exec rspec

# Run with coverage
bundle exec rspec --format documentation

# Run specific tests
bundle exec rspec spec/models/
bundle exec rspec spec/controllers/
```

## 🛠️ Development

```bash
# Install dependencies
bundle install

# Database setup
rails db:create db:migrate

# Start development server  
rails server

# Start with automatic reloading
bin/dev

# Rails console
rails console

# Generate documentation
bundle exec yard doc
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Run the test suite (`bundle exec rspec`)
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with Ruby on Rails
- Rich text editing powered by Trix
- Authentication via Bluesky's AT Protocol
- Inspired by Medium's clean writing experience

---

**Made with ❤️ for the decentralized web**
