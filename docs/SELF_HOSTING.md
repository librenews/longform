# Self-Hosting Longform

This guide will help you set up your own Longform instance for complete control over your content and data.

## Prerequisites

- Docker and Docker Compose (recommended), OR
- Ruby 3.2+, PostgreSQL 14+, Node.js 18+
- A Bluesky account for OAuth setup
- A domain name (for production)

## Quick Start with Docker

### 1. Clone and Setup

```bash
git clone https://github.com/yourusername/longform.git
cd longform
cp .env.example .env
```

### 2. Configure Environment

Edit `.env` with your settings:

```env
# Database
POSTGRES_DB=longform_production
POSTGRES_USER=longform
POSTGRES_PASSWORD=your_secure_password
DATABASE_URL=postgresql://longform:your_secure_password@db:5432/longform_production

# Rails
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key_base_64_chars_minimum
RAILS_LOG_TO_STDOUT=true

# Bluesky OAuth
BLUESKY_CLIENT_ID=your_bluesky_client_id
BLUESKY_CLIENT_SECRET=your_bluesky_client_secret
BLUESKY_REDIRECT_URI=https://yourdomain.com/auth/bluesky/callback

# Application Settings
APP_HOST=yourdomain.com
APP_NAME="Your Longform Instance"
```

### 3. Generate Secret Key

```bash
docker-compose run --rm app rails secret
# Copy the output to SECRET_KEY_BASE in .env
```

### 4. Start Services

```bash
docker-compose up -d
```

### 5. Initialize Database

```bash
docker-compose exec app rails db:create db:migrate
```

### 6. Set Up Reverse Proxy (Production)

For production, use nginx or Caddy:

**Nginx example:**
```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /path/to/your/cert.pem;
    ssl_certificate_key /path/to/your/key.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Caddy example:**
```
yourdomain.com {
    reverse_proxy localhost:3000
}
```

## Manual Installation

### 1. System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y ruby ruby-dev postgresql postgresql-contrib nodejs npm build-essential libpq-dev
```

**macOS:**
```bash
brew install ruby postgresql node
```

### 2. Database Setup

```bash
# Start PostgreSQL
sudo systemctl start postgresql  # Linux
brew services start postgresql   # macOS

# Create user and database
sudo -u postgres createuser -s longform
sudo -u postgres createdb longform_production -O longform
```

### 3. Application Setup

```bash
# Clone repository
git clone https://github.com/yourusername/longform.git
cd longform

# Install dependencies
bundle install
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Setup database
RAILS_ENV=production rails db:create db:migrate

# Precompile assets
RAILS_ENV=production rails assets:precompile

# Start application
RAILS_ENV=production rails server -b 0.0.0.0 -p 3000
```

## Bluesky OAuth Setup

### 1. Register Your Application

Visit your Bluesky settings and create a new app:

1. Go to Bluesky Settings > App Passwords
2. Create a new app password for your Longform instance
3. Note down the client ID and secret

### 2. Configure OAuth

Update your `.env` file:

```env
BLUESKY_CLIENT_ID=your_app_client_id
BLUESKY_CLIENT_SECRET=your_app_secret
BLUESKY_REDIRECT_URI=https://yourdomain.com/auth/bluesky/callback
```

### 3. Test Authentication

Visit `https://yourdomain.com` and test the "Sign in with Bluesky" flow.

## Monitoring and Maintenance

### Health Checks

The application includes health check endpoints:

- `GET /health` - Basic application health
- `GET /health/database` - Database connectivity
- `GET /health/detailed` - Comprehensive system status

### Logs

**Docker:**
```bash
# Application logs
docker-compose logs -f app

# Database logs
docker-compose logs -f db
```

**Manual:**
```bash
# Rails logs
tail -f log/production.log

# System logs
journalctl -u your-longform-service -f
```

### Backups

**Database backup:**
```bash
# Docker
docker-compose exec db pg_dump -U longform longform_production > backup.sql

# Manual
pg_dump -U longform longform_production > backup.sql
```

**File storage backup:**
```bash
# Backup uploaded files
tar -czf storage-backup.tar.gz storage/
```

### Updates

**Docker:**
```bash
git pull origin main
docker-compose build
docker-compose up -d
docker-compose exec app rails db:migrate
```

**Manual:**
```bash
git pull origin main
bundle install
npm install
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails assets:precompile
sudo systemctl restart your-longform-service
```

## Security Considerations

1. **HTTPS Only**: Always use SSL certificates in production
2. **Firewall**: Restrict access to only necessary ports
3. **Updates**: Keep the application and dependencies updated
4. **Backups**: Regular automated backups
5. **Monitoring**: Set up uptime and error monitoring

## Customization

### Branding

Edit these files to customize your instance:

- `app/views/layouts/application.html.erb` - Main layout
- `app/assets/stylesheets/application.scss` - Styles
- `config/application.rb` - Application name and settings

### Features

The application is designed to be easily extensible. See [DEVELOPMENT.md](DEVELOPMENT.md) for details on adding features.

## Troubleshooting

### Common Issues

**Database connection error:**
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Verify connection string in .env
```

**Assets not loading:**
```bash
# Precompile assets
RAILS_ENV=production rails assets:precompile
```

**OAuth errors:**
- Verify BLUESKY_REDIRECT_URI matches your domain
- Check client ID and secret are correct
- Ensure your domain is accessible from the internet

### Getting Help

- Check the [main documentation](../README.md)
- Open an issue on GitHub
- Join our community discussions

## Performance Optimization

### Database

- Enable connection pooling
- Set up read replicas for high traffic
- Regular maintenance with `VACUUM` and `ANALYZE`

### Application

- Use a CDN for static assets
- Enable caching with Redis
- Monitor with APM tools like New Relic or DataDog

### Infrastructure

- Use multiple application servers behind a load balancer
- Set up database backups and monitoring
- Implement log aggregation and alerting
