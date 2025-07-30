# AT Protocol Key Management

This document explains how to generate and manage AT Protocol keys for Longform.

## Overview

Longform uses AT Protocol (Bluesky) OAuth for authentication, which requires:
- An EC P-256 private key for signing JWT tokens
- A corresponding JWK (JSON Web Key) for the public key

**IMPORTANT**: These keys must be unique per environment and should NEVER be committed to version control.

## Key Generation

### Automatic Generation

Keys are automatically generated when first needed. The application will create them if they don't exist when:
- The application starts and needs to authenticate
- Someone accesses the OAuth client metadata endpoint
- You run the setup script

### Manual Generation

You can manually generate new keys using the Rails task:

```bash
# Generate new keys (will backup existing ones)
rails atproto:rotate_keys

# Or just generate keys without backup
rails atproto:generate_keys
```

### Development Setup

The development setup script automatically generates keys:

```bash
./scripts/dev-setup.sh
```

## File Locations

Keys are stored in:
- `config/atproto_private_key.pem` - Private key (ES256)
- `config/atproto_jwk.json` - Public key in JWK format

**Security**: These files have 600 permissions (read/write for owner only).

## Security Best Practices

### Development
- Keys are auto-generated per developer
- Each developer gets unique keys
- Keys are in `.gitignore` and won't be committed

### Production
- Generate unique keys for each production instance
- Store keys securely (consider using secrets management)
- Rotate keys periodically using `rails atproto:rotate_keys`
- Backup keys before rotation

### Multi-Environment
- **Never share keys between environments**
- Each environment (dev, staging, prod) should have unique keys
- Keys are tied to the specific OAuth client metadata URL

## Key Rotation

To rotate keys (recommended periodically):

```bash
rails atproto:rotate_keys
```

This will:
1. Backup existing keys with timestamp
2. Generate new key pair
3. Update JWK with new public key
4. Log the changes

## Troubleshooting

### Missing Keys Error
If you get authentication errors about missing keys:

```bash
rails atproto:generate_keys
```

### Invalid JWK Format
If OAuth fails due to JWK issues:

```bash
rails atproto:rotate_keys
```

### Permission Errors
If you can't read key files:

```bash
chmod 600 config/atproto_private_key.pem
chmod 600 config/atproto_jwk.json
```

## Client Metadata

The OAuth client metadata is served dynamically at:
- Development (tunnel): `https://dev.libre.news/oauth/client-metadata.json`
- Development (localhost): `http://localhost:3001/oauth/client-metadata.json`
- Production: `https://yourdomain.com/oauth/client-metadata.json`

This endpoint includes the current public key (JWK) and is automatically updated when keys are rotated.

## Environment Variables

No environment variables are needed for key management. Keys are file-based and environment-specific.

However, make sure these are set correctly:
- `APP_URL` - Used in client metadata and redirect URIs
- `APP_HOST` - Used for request validation

## Migration from Committed Keys

If you had previously committed keys (security issue), they have been:
1. Removed from git tracking
2. Added to `.gitignore`
3. Will be regenerated automatically

The old keys are now invalid and new unique keys will be generated per environment.
