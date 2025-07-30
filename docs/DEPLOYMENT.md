# Deployment Guide

This guide covers various deployment options for Longform, from simple single-server setups to scalable cloud deployments.

## Quick Deployment Options

### 1. Digital Ocean App Platform (Easiest)

Digital Ocean's App Platform provides the simplest deployment path:

```yaml
# .do/app.yaml
name: longform
services:
- name: web
  source_dir: /
  github:
    repo: your-username/longform
    branch: main
  run_command: bundle exec rails server -b 0.0.0.0 -p $PORT
  environment_slug: ruby
  instance_count: 1
  instance_size_slug: basic-xxs
  env:
  - key: RAILS_ENV
    value: production
  - key: SECRET_KEY_BASE
    scope: SECRET
  - key: BLUESKY_CLIENT_ID
    scope: SECRET
  - key: BLUESKY_CLIENT_SECRET
    scope: SECRET
databases:
- name: longform-db
  engine: PG
  version: "14"
```

### 2. Heroku Deployment

Deploy to Heroku with a few commands:

```bash
# Install Heroku CLI and login
heroku login

# Create application
heroku create your-longform-app

# Add PostgreSQL
heroku addons:create heroku-postgresql:mini

# Set environment variables
heroku config:set RAILS_ENV=production
heroku config:set SECRET_KEY_BASE=$(rails secret)
heroku config:set BLUESKY_CLIENT_ID=your_client_id
heroku config:set BLUESKY_CLIENT_SECRET=your_client_secret
heroku config:set BLUESKY_REDIRECT_URI=https://your-longform-app.herokuapp.com/auth/bluesky/callback

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
```

### 3. Railway Deployment

Railway offers a simple, modern deployment platform:

1. Connect your GitHub repository
2. Set environment variables in the Railway dashboard
3. Deploy automatically on push

## Docker Deployment

### Single Server with Docker Compose

Best for small to medium instances:

```bash
# Clone and configure
git clone https://github.com/your-username/longform.git
cd longform
cp .env.example .env
# Edit .env with your configuration

# Generate secret key
SECRET_KEY_BASE=$(docker-compose run --rm app rails secret)
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" >> .env

# Start services
docker-compose up -d

# Initialize database
docker-compose exec app rails db:create db:migrate

# Your instance is now running at https://yourdomain.com
```

### Production Docker Setup

For production with SSL and monitoring:

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  app:
    build: .
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://longform:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - ./storage:/app/storage
      - ./log:/app/log
    restart: unless-stopped
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./public:/var/www/public:ro
    depends_on:
      - app
    restart: unless-stopped

  db:
    image: postgres:16
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  grafana_data:
```

## Cloud Provider Deployments

### AWS Deployment

#### Option 1: Elastic Beanstalk

```bash
# Install EB CLI
pip install awsebcli

# Initialize
eb init longform

# Create environment
eb create production

# Deploy
eb deploy
```

#### Option 2: ECS with Fargate

```yaml
# ecs-task-definition.json
{
  "family": "longform",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "longform-app",
      "image": "your-registry/longform:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "RAILS_ENV", "value": "production"},
        {"name": "DATABASE_URL", "value": "postgresql://..."}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/longform",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Google Cloud Platform

#### Cloud Run Deployment

```bash
# Build and push to Container Registry
gcloud builds submit --tag gcr.io/PROJECT_ID/longform

# Deploy to Cloud Run
gcloud run deploy longform \
  --image gcr.io/PROJECT_ID/longform \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars RAILS_ENV=production,DATABASE_URL=postgresql://...
```

### Microsoft Azure

#### Container Instances

```bash
# Create resource group
az group create --name longform-rg --location eastus

# Create container instance
az container create \
  --resource-group longform-rg \
  --name longform-instance \
  --image your-registry/longform:latest \
  --dns-name-label longform-unique \
  --ports 3000 \
  --environment-variables RAILS_ENV=production DATABASE_URL=postgresql://...
```

## Kubernetes Deployment

### Basic Kubernetes Setup

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: longform

---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: longform-config
  namespace: longform
data:
  RAILS_ENV: "production"
  APP_HOST: "longform.yourdomain.com"

---
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: longform-secrets
  namespace: longform
type: Opaque
stringData:
  SECRET_KEY_BASE: "your-secret-key"
  DATABASE_URL: "postgresql://..."
  BLUESKY_CLIENT_SECRET: "your-secret"

---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: longform-app
  namespace: longform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: longform
  template:
    metadata:
      labels:
        app: longform
    spec:
      containers:
      - name: longform
        image: your-registry/longform:latest
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: longform-config
        - secretRef:
            name: longform-secrets
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"

---
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: longform-service
  namespace: longform
spec:
  selector:
    app: longform
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: ClusterIP

---
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longform-ingress
  namespace: longform
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  tls:
  - hosts:
    - longform.yourdomain.com
    secretName: longform-tls
  rules:
  - host: longform.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longform-service
            port:
              number: 80
```

### Deploy to Kubernetes

```bash
# Apply configurations
kubectl apply -f k8s/

# Check deployment
kubectl get pods -n longform
kubectl get services -n longform
kubectl get ingress -n longform

# View logs
kubectl logs -f deployment/longform-app -n longform
```

## Database Setup

### Managed Database Services

**AWS RDS:**
```bash
# Create PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier longform-prod \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 14.9 \
  --allocated-storage 20 \
  --master-username longform \
  --master-user-password your-password
```

**Google Cloud SQL:**
```bash
# Create PostgreSQL instance
gcloud sql instances create longform-prod \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1
```

### Database Migration in Production

```bash
# Run migrations during deployment
rails db:migrate

# Check migration status
rails db:migrate:status

# Rollback if needed
rails db:rollback STEP=1
```

## SSL/TLS Configuration

### Let's Encrypt with Certbot

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d yourdomain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Cloudflare SSL

1. Add your domain to Cloudflare
2. Set SSL/TLS mode to "Full (strict)"
3. Enable "Always Use HTTPS"
4. Configure origin certificates

## Monitoring and Logging

### Application Performance Monitoring

**New Relic:**
```ruby
# Gemfile
gem 'newrelic_rpm'

# config/newrelic.yml
production:
  license_key: 'your-license-key'
  app_name: 'Longform Production'
  monitor_mode: true
```

**Sentry for Error Tracking:**
```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = Rails.env
end
```

### Log Management

**Centralized Logging with ELK Stack:**
```yaml
# docker-compose.logging.yml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
      - ./log:/var/log/rails

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
```

## Backup and Disaster Recovery

### Automated Backups

```bash
#!/bin/bash
# backup.sh

# Database backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pg_dump $DATABASE_URL > backups/db_backup_$TIMESTAMP.sql

# File storage backup
tar -czf backups/storage_backup_$TIMESTAMP.tar.gz storage/

# Upload to S3
aws s3 cp backups/ s3://your-backup-bucket/ --recursive

# Cleanup old backups (keep 30 days)
find backups/ -name "*.sql" -mtime +30 -delete
find backups/ -name "*.tar.gz" -mtime +30 -delete
```

### Disaster Recovery Plan

1. **Database Recovery:**
   ```bash
   # Restore from backup
   psql $DATABASE_URL < backups/db_backup_latest.sql
   ```

2. **Application Recovery:**
   ```bash
   # Redeploy application
   docker-compose up -d
   
   # Restore file storage
   tar -xzf backups/storage_backup_latest.tar.gz
   ```

3. **DNS Failover:**
   - Configure DNS with low TTL
   - Set up secondary deployment
   - Use health checks for automatic failover

## Performance Optimization

### Application Server Tuning

```ruby
# config/puma.rb for production
workers ENV.fetch("WEB_CONCURRENCY") { 4 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
```

### Database Optimization

```sql
-- Add indexes for common queries
CREATE INDEX idx_posts_user_id_created_at ON posts (user_id, created_at DESC);
CREATE INDEX idx_posts_published_at ON posts (published_at) WHERE published_at IS NOT NULL;

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM posts WHERE user_id = 1 ORDER BY created_at DESC LIMIT 10;
```

### CDN Configuration

**Cloudflare:**
- Enable auto-minification for CSS, JS, HTML
- Set caching rules for static assets
- Enable Brotli compression

**AWS CloudFront:**
```json
{
  "DistributionConfig": {
    "Origins": [{
      "DomainName": "yourdomain.com",
      "Id": "longform-origin",
      "CustomOriginConfig": {
        "HTTPPort": 443,
        "OriginProtocolPolicy": "https-only"
      }
    }],
    "DefaultCacheBehavior": {
      "TargetOriginId": "longform-origin",
      "ViewerProtocolPolicy": "redirect-to-https",
      "Compress": true
    }
  }
}
```

## Security Hardening

### Application Security

```ruby
# config/application.rb
config.force_ssl = true
config.ssl_options = {
  hsts: { expires: 1.year, subdomains: true, preload: true }
}

# Rate limiting
config.middleware.use Rack::Attack

# Security headers
config.middleware.use Rack::Protection
```

### Infrastructure Security

```bash
# Firewall configuration
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw --force enable

# Fail2ban for SSH protection
apt install fail2ban
systemctl enable fail2ban
```

## Troubleshooting Deployments

### Common Issues

**Memory Issues:**
```bash
# Check memory usage
free -h
docker stats

# Optimize Ruby memory
export RUBY_GC_HEAP_GROWTH_FACTOR=1.1
export RUBY_GC_HEAP_GROWTH_MAX_SLOTS=1000
```

**Database Connection Issues:**
```bash
# Test database connectivity
pg_isready -h db_host -p 5432 -U username

# Check connection pool
rails db:pool:status
```

**Asset Issues:**
```bash
# Precompile assets
RAILS_ENV=production rails assets:precompile

# Clear asset cache
RAILS_ENV=production rails assets:clobber
```

### Deployment Checklist

Before going live:

- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] Assets precompiled
- [ ] SSL certificate installed
- [ ] Health checks passing
- [ ] Backups configured
- [ ] Monitoring set up
- [ ] DNS records updated
- [ ] Firewall configured
- [ ] Security headers enabled

---

For specific deployment questions, check the troubleshooting section or open an issue on GitHub.
