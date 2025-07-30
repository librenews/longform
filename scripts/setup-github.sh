#!/bin/bash

# GitHub Repository Setup Script
# Run this script after creating your GitHub repository

echo "🚀 Setting up GitHub repository for Longform..."

# Check if git remote already exists
if git remote get-url origin &>/dev/null; then
    echo "✅ Git remote 'origin' already configured"
    git remote -v
else
    echo "❓ Please enter your GitHub repository URL (e.g., https://github.com/username/longform.git):"
    read -r repo_url
    
    if [[ -n "$repo_url" ]]; then
        git remote add origin "$repo_url"
        echo "✅ Added remote origin: $repo_url"
    else
        echo "❌ No repository URL provided"
        exit 1
    fi
fi

# Push to GitHub
echo "📤 Pushing to GitHub..."
git branch -M main
git push -u origin main

echo "🎉 Repository setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Visit your GitHub repository"
echo "2. Add repository description and topics"
echo "3. Configure any branch protection rules"
echo "4. Set up GitHub Pages (if desired)"
echo "5. Configure any secrets for CI/CD"
echo ""
echo "🔧 For local development:"
echo "bundle install"
echo "rails db:create db:migrate db:seed"
echo "rails server"
