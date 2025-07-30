# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete post management system with CRUD operations
- Post status system: Draft, Published, Archived, Failed
- Rich text editor with Trix and auto-save functionality
- Archive/unarchive functionality for temporary content hiding
- Delete functionality with confirmation dialogs
- Search and filtering system for posts
- Word count and reading time calculation
- Responsive post cards with status indicators
- Bluesky OAuth integration with avatar fetching
- PicoCSS-based responsive design system
- Comprehensive post metadata display
- Status-based navigation and filtering
- Auto-save functionality for post drafts
- Confirmation dialogs for destructive actions

### Features Implemented
- **Post Management**: Full CRUD with status transitions
- **Editor Experience**: Rich text editing with real-time save
- **Content Organization**: Draft, publish, archive workflow
- **Search & Discovery**: Filter posts by status and search content
- **User Interface**: Clean, responsive design with semantic styling
- **Data Safety**: Confirmation prompts and reversible operations

### Technical Stack
- Ruby on Rails 7.2.2
- PostgreSQL database
- Action Text for rich content
- Turbo + Stimulus for interactivity
- PicoCSS for styling
- AT Protocol OAuth for authentication

### Infrastructure
- Docker containerization
- Database migrations
- Seed data for development
- Test suite setup with RSpec
- Development tooling and scripts

## [0.1.0] - 2025-01-30

### Added
- Initial Rails application setup
- Basic project structure
- Gemfile with core dependencies
- Database configuration
- Docker setup with Dockerfile and docker-compose.yml
- Basic routing and controller structure
- Initial post model and migrations
- Authentication system foundation
- Development environment configuration

### Project Structure
- MVC architecture with Rails conventions
- Asset pipeline with importmap
- Stimulus controllers for JavaScript
- Action Text for rich content
- OAuth integration setup
- Test environment with RSpec

---

**Note**: This project is under active development. Features and APIs may change before the first stable release.
