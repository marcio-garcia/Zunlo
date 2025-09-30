# App Store Metadata Management Guide

This guide explains how to use fastlane to manage your App Store metadata efficiently.

## 📁 Directory Structure

```
fastlane/
├── metadata/
│   ├── en-US/                    # English (US) metadata
│   │   ├── name.txt             # App name (30 chars max)
│   │   ├── subtitle.txt         # App subtitle (30 chars max)
│   │   ├── description.txt      # App description (4000 chars max)
│   │   ├── keywords.txt         # Keywords, comma-separated (100 chars max)
│   │   └── release_notes.txt    # What's new in this version
│   ├── pt-BR/                   # Portuguese (Brazil) metadata
│   │   └── [same files as en-US]
│   ├── review_information/       # App Review information
│   │   ├── first_name.txt
│   │   ├── last_name.txt
│   │   ├── email_address.txt
│   │   ├── phone_number.txt
│   │   └── notes.txt
│   └── rating_config.json       # Age rating configuration
├── screenshots/
│   ├── en-US/                   # English screenshots
│   └── pt-BR/                   # Portuguese screenshots
└── Deliverfile                  # deliver configuration
```

## 🚀 Available Commands

### Environment Configuration
```bash
# Set environment before running fastlane commands
source fastlane/scripts/set_env.sh prod     # Production
source fastlane/scripts/set_env.sh staging  # Staging (or 'stg')
source fastlane/scripts/set_env.sh stg      # Staging (short form)
source fastlane/scripts/set_env.sh dev      # Development

# Or set manually
export APP_BUNDLE_ID="net.loginode.zunloapp.stg"
```

### Validation
```bash
# Validate metadata files locally (recommended before upload)
fastlane validate_metadata
```

### Upload Operations
```bash
# Upload only metadata (no screenshots or binary)
fastlane upload_metadata

# Environment-specific uploads
fastlane upload_metadata_prod     # Production
fastlane upload_metadata_staging  # Staging
fastlane upload_metadata_dev      # Development

# Upload only screenshots (no metadata or binary)
fastlane upload_screenshots

# Generate screenshots for specific environment
fastlane screenshots_env bundle_id:net.loginode.zunloapp.stg

# Generate screenshots and upload everything
fastlane prepare_app_store
```

### Preview
```bash
# Preview what would be uploaded without actually uploading
fastlane preview_metadata
```

## 📝 Editing Metadata

### App Description Tips
- Maximum 4000 characters
- Use bullet points for features
- Include keywords naturally
- Highlight unique selling points

### Keywords Strategy
- Maximum 100 characters total
- Separate with commas
- Research competitor keywords
- Avoid repetition of words in app name

### Subtitle Guidelines
- Maximum 30 characters
- Summarize main value proposition
- Complement the app name

## 🔍 Validation Rules

The `validate_metadata` lane checks:
- ✅ All required files exist
- ✅ No empty files
- ✅ Character limits respected
- ✅ Proper file encoding

## 🌍 Localization

Currently configured for:
- **en-US**: English (United States)
- **pt-BR**: Portuguese (Brazil)

To add more languages:
1. Create new directory in `metadata/[locale]/`
2. Copy metadata files and translate content
3. Update validation rules in Fastfile

## 🔄 Environment Aliases

The environment script supports multiple aliases for convenience:

| Environment | Aliases | Bundle ID |
|-------------|---------|-----------|
| Production | `prod`, `production` | `net.loginode.zunloapp` |
| Staging | `staging`, `stage`, `stg` | `net.loginode.zunloapp.stg` |
| Development | `dev`, `development`, `debug` | `net.loginode.zunloapp.dev` |

## ⚙️ Configuration

### App Information
- Production Bundle ID: `net.loginode.zunloapp`
- Staging Bundle ID: `net.loginode.zunloapp.stg`
- Development Bundle ID: `net.loginode.zunloapp.dev`
- Apple ID: `marcio@loginode.com`
- Price Tier: 0 (Free)

### Review Information
Update the files in `review_information/` with:
- Your contact details
- Special testing instructions
- Demo account info (if needed)

## 🔒 Security Notes

- Never commit real credentials to git
- Use App Store Connect API keys for automation
- Keep sensitive review information in separate, secure files

## 📱 Screenshot Integration

Screenshots are automatically organized by:
- Device type (iPhone, iPad)
- Language (en-US, pt-BR)
- Screen size

Generated screenshots from `fastlane screenshots` are automatically placed in the correct directories for upload.

## 🚨 Before First Upload

1. **Set up authentication**: For MFA accounts, create App Store Connect API Key (see `API_KEY_SETUP.md`)
2. **Update review information**: Edit files in `review_information/`
3. **Verify app details**: Check bundle ID in `Appfile`
4. **Run validation**: `fastlane validate_metadata`
5. **Preview first**: `fastlane preview_metadata`

## 📈 Best Practices

1. **Version control**: Keep all metadata in git
2. **Regular validation**: Run `validate_metadata` before releases
3. **A/B testing**: Test different descriptions/keywords
4. **Update regularly**: Keep release notes current
5. **Localize properly**: Ensure translations are accurate

## 🔧 Troubleshooting

### Common Issues
- **Authentication errors**: Check App Store Connect API credentials
- **Character limit errors**: Use validation to catch before upload
- **Missing files**: Ensure all required metadata files exist

### Getting Help
- Run `fastlane validate_metadata` for detailed error messages
- Check fastlane documentation: https://docs.fastlane.tools/actions/deliver/
- Review App Store Connect guidelines

## 📋 Quick Reference

### Environment Setup
```bash
# Production
source fastlane/scripts/set_env.sh prod
fastlane upload_metadata

# Staging (multiple options)
source fastlane/scripts/set_env.sh stg
source fastlane/scripts/set_env.sh staging
source fastlane/scripts/set_env.sh stage

# Development
source fastlane/scripts/set_env.sh dev
```

### Bundle IDs
- **Production**: `net.loginode.zunloapp`
- **Staging**: `net.loginode.zunloapp.stg`
- **Development**: `net.loginode.zunloapp.dev`

### Common Commands
```bash
fastlane validate_metadata           # Always run first
fastlane upload_metadata_prod        # Direct production upload
fastlane upload_metadata_staging     # Direct staging upload
fastlane upload_metadata_dev         # Direct development upload
fastlane prepare_app_store           # Screenshots + metadata
```