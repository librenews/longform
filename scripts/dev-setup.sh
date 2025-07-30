#!/bin/bash

# Development Environment Setup Script for Longform
# This script helps new developers configure their local development environment

set -e

echo "🚀 Setting up Longform development environment..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📋 Creating .env from template..."
    cp .env.development .env
    echo "✅ Created .env file"
else
    echo "✅ .env file already exists"
fi

# Prompt for configuration
echo ""
echo "🔧 Let's configure your development environment:"
echo ""

# Get APP_HOST
read -p "Enter your development host (default: localhost:3000): " app_host
app_host=${app_host:-localhost:3000}

# Get APP_URL  
if [[ $app_host == localhost:* ]] || [[ $app_host == 127.0.0.1:* ]]; then
    app_url="http://$app_host"
else
    app_url="https://$app_host"
fi

echo "📝 Updating .env with your configuration..."

# Update .env file
sed -i.bak "s|APP_HOST=.*|APP_HOST=$app_host|g" .env
sed -i.bak "s|APP_URL=.*|APP_URL=$app_url|g" .env
sed -i.bak "s|BLUESKY_REDIRECT_URI=.*|BLUESKY_REDIRECT_URI=$app_url/auth/atproto/callback|g" .env

# Remove backup file
rm .env.bak

echo "✅ Configuration updated:"
echo "   APP_HOST: $app_host"
echo "   APP_URL: $app_url"
echo "   Redirect URI: $app_url/auth/atproto/callback"
echo ""

echo "📦 Installing dependencies..."
if command -v bundle >/dev/null 2>&1; then
    bundle install
    echo "✅ Ruby gems installed"
else
    echo "❌ Bundler not found. Please install Ruby and Bundler first."
    exit 1
fi

echo ""
echo "🗄️  Setting up database..."
if rails db:version >/dev/null 2>&1; then
    echo "✅ Database already exists"
else
    rails db:create
    echo "✅ Database created"
fi

rails db:migrate
echo "✅ Database migrated"

if rails db:seed >/dev/null 2>&1; then
    echo "✅ Database seeded"
fi

echo ""
echo "🔑 Generating AT Protocol keys..."
if [ -f config/atproto_private_key.pem ] && [ -f config/atproto_jwk.json ]; then
    echo "✅ AT Protocol keys already exist"
else
    rails atproto:rotate_keys >/dev/null 2>&1
    echo "✅ AT Protocol keys generated"
fi

echo ""
echo "🎉 Development environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Configure Bluesky OAuth credentials in .env:"
echo "   - Get credentials from https://bsky.social/settings/app-passwords"
echo "   - Update BLUESKY_CLIENT_ID and BLUESKY_CLIENT_SECRET"
echo ""
echo "2. Start the development server on port 3001:"
echo "   rails server -p 3001"
echo ""
echo "3. Set up your tunnel to dev.libre.news pointing to localhost:3001"
echo ""
echo "4. Visit your application:"
echo "   https://dev.libre.news"
echo ""
echo "💡 Need help? Check the documentation in docs/ or README.md"
