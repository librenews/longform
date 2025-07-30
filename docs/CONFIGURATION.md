# Configuration Guide

This guide covers all configuration options for Longform, whether you're running a hosted instance or self-hosting.

## Environment Variables

### Required Variables

These variables are required for the application to run:

```env
# Database Configuration
DATABASE_URL=postgresql://user:password@host:port/database_name

# Rails Configuration  
SECRET_KEY_BASE=your_64_character_secret_key
RAILS_ENV=production

# Bluesky OAuth
BLUESKY_CLIENT_ID=your_bluesky_client_id
BLUESKY_CLIENT_SECRET=your_bluesky_client_secret
BLUESKY_REDIRECT_URI=https://yourdomain.com/auth/bluesky/callback
```

### Optional Variables

```env
# Application Settings
APP_NAME="Your Longform Instance"
APP_HOST=yourdomain.com
APP_DESCRIPTION="Write and publish longform content to Bluesky"

# Performance Settings
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
DATABASE_POOL_SIZE=5

# Storage Configuration
ACTIVE_STORAGE_VARIANT_PROCESSOR=mini_magick
MAX_FILE_SIZE=10485760  # 10MB in bytes

# Email Configuration (for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_DOMAIN=yourdomain.com

# Caching (Redis)
REDIS_URL=redis://localhost:6379/0

# Analytics (optional)
GOOGLE_ANALYTICS_ID=GA_MEASUREMENT_ID
PLAUSIBLE_DOMAIN=yourdomain.com

# Security
FORCE_SSL=true
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
```

## Database Configuration

### PostgreSQL Settings

Recommended PostgreSQL configuration for production:

```sql
-- In postgresql.conf
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
```

### Connection Pooling

For high-traffic instances, configure connection pooling:

```env
DATABASE_POOL_SIZE=25
DATABASE_TIMEOUT=5000
```

### Read Replicas

For scaling read operations:

```env
DATABASE_URL=postgresql://user:password@primary:5432/longform
DATABASE_REPLICA_URL=postgresql://user:password@replica:5432/longform
```

## Bluesky Integration

### OAuth Setup

1. **Register Application**: Create app credentials in Bluesky settings
2. **Configure Redirect URI**: Must exactly match your domain
3. **Set Environment Variables**: Add client ID and secret

```env
# Development
BLUESKY_REDIRECT_URI=http://localhost:3000/auth/bluesky/callback

# Production  
BLUESKY_REDIRECT_URI=https://yourdomain.com/auth/bluesky/callback
```

### AT Protocol Settings

```env
# Bluesky API endpoints
BLUESKY_API_URL=https://bsky.social/xrpc
BLUESKY_OAUTH_URL=https://bsky.social/oauth

# Request timeouts
BLUESKY_TIMEOUT=30
BLUESKY_RETRY_ATTEMPTS=3
```

## File Storage

### Local Storage (Default)

Files stored in the application's storage directory:

```env
ACTIVE_STORAGE_SERVICE=local
```

### Amazon S3

For production deployments:

```env
ACTIVE_STORAGE_SERVICE=amazon
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
AWS_BUCKET=your-longform-bucket
```

### Other Cloud Providers

**Google Cloud Storage:**
```env
ACTIVE_STORAGE_SERVICE=google
GCS_PROJECT=your-project-id
GCS_BUCKET=your-bucket-name
GCS_CREDENTIALS=path/to/credentials.json
```

**Microsoft Azure:**
```env
ACTIVE_STORAGE_SERVICE=microsoft
AZURE_STORAGE_ACCOUNT_NAME=your_account
AZURE_STORAGE_ACCESS_KEY=your_key
AZURE_STORAGE_CONTAINER=your_container
```

## Caching

### Redis Configuration

```env
REDIS_URL=redis://localhost:6379/0
REDIS_CACHE_DB=1
REDIS_SIDEKIQ_DB=2
```

### Cache Settings

```env
# Cache expiration times (in seconds)
CACHE_EXPIRES_IN=3600
FRAGMENT_CACHE_EXPIRES_IN=1800
HTTP_CACHE_EXPIRES_IN=300
```

## Email Configuration

### SMTP Settings

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=notifications@yourdomain.com
SMTP_PASSWORD=your_app_password
SMTP_DOMAIN=yourdomain.com
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
```

### Email Providers

**Sendgrid:**
```env
SENDGRID_API_KEY=your_api_key
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
```

**Mailgun:**
```env
MAILGUN_API_KEY=your_api_key
MAILGUN_DOMAIN=mg.yourdomain.com
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
```

## Security Configuration

### SSL/TLS

```env
FORCE_SSL=true
SSL_REDIRECT=true
HSTS_MAX_AGE=31536000
```

### Content Security Policy

```env
CSP_ENABLED=true
CSP_REPORT_ONLY=false
CSP_REPORT_URI=/csp-violation-report-endpoint
```

### Rate Limiting

```env
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_HOUR=1000
RATE_LIMIT_BURST=50
```

### CORS Configuration

```env
CORS_ENABLED=true
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

## Monitoring and Logging

### Application Monitoring

```env
# New Relic
NEW_RELIC_LICENSE_KEY=your_license_key
NEW_RELIC_APP_NAME=Longform Production

# Sentry
SENTRY_DSN=your_sentry_dsn
SENTRY_ENVIRONMENT=production

# DataDog
DD_API_KEY=your_datadog_api_key
DD_APP_KEY=your_datadog_app_key
```

### Logging

```env
RAILS_LOG_LEVEL=info
RAILS_LOG_TO_STDOUT=true
LOG_RETENTION_DAYS=30
```

### Health Checks

```env
HEALTH_CHECK_ENABLED=true
HEALTH_CHECK_DATABASE=true
HEALTH_CHECK_REDIS=true
HEALTH_CHECK_STORAGE=true
```

## Performance Tuning

### Application Server

```env
WEB_CONCURRENCY=4
RAILS_MAX_THREADS=5
RAILS_MIN_THREADS=5
BOOTSNAP_CACHE_DIR=/tmp/bootsnap-cache
```

### Database Optimization

```env
DATABASE_POOL_SIZE=25
DATABASE_CHECKOUT_TIMEOUT=5
DATABASE_STATEMENT_TIMEOUT=30000
```

### Asset Compilation

```env
RAILS_SERVE_STATIC_FILES=true
RAILS_ASSET_COMPRESSION=true
ASSETS_PRECOMPILE_CACHE=true
```

## Feature Flags

### Content Features

```env
# Enable/disable features
ENABLE_RICH_TEXT_EDITOR=true
ENABLE_IMAGE_UPLOADS=true
ENABLE_DRAFT_SHARING=false
MAX_POST_LENGTH=10000
```

### Social Features

```env
ENABLE_COMMENTS=false
ENABLE_LIKES=false
ENABLE_SHARING=true
```

### Administrative Features

```env
ENABLE_ADMIN_DASHBOARD=true
ENABLE_USER_ANALYTICS=true
ENABLE_CONTENT_MODERATION=false
```

## Customization

### Branding

```env
APP_NAME="Your Longform Instance"
APP_LOGO_URL=https://yourdomain.com/logo.png
APP_FAVICON_URL=https://yourdomain.com/favicon.ico
BRAND_COLOR=#1da1f2
```

### UI Customization

```env
THEME=default
CUSTOM_CSS_URL=https://yourdomain.com/custom.css
CUSTOM_JS_URL=https://yourdomain.com/custom.js
```

## Development Configuration

### Development Environment

```env
RAILS_ENV=development
DATABASE_URL=postgresql://localhost/longform_development
BLUESKY_REDIRECT_URI=http://localhost:3000/auth/bluesky/callback
```

### Testing Environment

```env
RAILS_ENV=test
DATABASE_URL=postgresql://localhost/longform_test
DISABLE_SPRING=true
```

## Configuration Validation

The application includes configuration validation to help identify issues:

```bash
# Check configuration
rails config:validate

# Show current configuration
rails config:show

# Test external services
rails config:test_services
```

## Environment-Specific Configurations

### Development

Create `.env.development`:
```env
RAILS_ENV=development
DATABASE_URL=postgresql://localhost/longform_development
BLUESKY_CLIENT_ID=dev_client_id
BLUESKY_CLIENT_SECRET=dev_client_secret
BLUESKY_REDIRECT_URI=http://localhost:3000/auth/bluesky/callback
RAILS_LOG_LEVEL=debug
```

### Staging

Create `.env.staging`:
```env
RAILS_ENV=production
DATABASE_URL=postgresql://staging-db/longform_staging
APP_HOST=staging.yourdomain.com
BLUESKY_REDIRECT_URI=https://staging.yourdomain.com/auth/bluesky/callback
```

### Production

Create `.env.production`:
```env
RAILS_ENV=production
DATABASE_URL=postgresql://prod-db/longform_production
APP_HOST=yourdomain.com
FORCE_SSL=true
BLUESKY_REDIRECT_URI=https://yourdomain.com/auth/bluesky/callback
```

## Configuration Management

### Using Rails Credentials

For sensitive data, use Rails encrypted credentials:

```bash
# Edit credentials
EDITOR=nano rails credentials:edit

# In credentials.yml.enc
bluesky:
  client_id: your_client_id
  client_secret: your_client_secret

database:
  password: your_db_password
```

### Using External Configuration Services

**Vault:**
```env
VAULT_ENABLED=true
VAULT_URL=https://vault.yourdomain.com
VAULT_TOKEN=your_vault_token
```

**AWS Secrets Manager:**
```env
AWS_SECRETS_ENABLED=true
AWS_SECRETS_REGION=us-east-1
AWS_SECRET_NAME=longform/production
```

## Troubleshooting Configuration

### Common Issues

**Database connection errors:**
- Verify DATABASE_URL format
- Check network connectivity
- Ensure PostgreSQL is running

**OAuth failures:**
- Verify BLUESKY_REDIRECT_URI matches exactly
- Check client ID and secret
- Ensure HTTPS in production

**File upload issues:**
- Check storage service configuration
- Verify permissions and credentials
- Test storage connectivity

### Configuration Testing

```bash
# Test database connection
rails db:migrate:status

# Test storage
rails storage:test

# Test email
rails email:test

# Test Bluesky integration
rails bluesky:test_connection
```

---

For additional help with configuration, see the [Self-Hosting Guide](SELF_HOSTING.md) or open an issue on GitHub.
