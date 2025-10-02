# TestFlight & App Store Deployment Guide

This guide explains how to build and deploy your app to TestFlight and the App Store using fastlane.

## 🚀 Quick Start

### Deploy to TestFlight (Internal Testing)

```bash
fastlane beta
```

This will:
1. ✅ Increment build number automatically
2. ✅ Build the app with "Zunlo" scheme (Release configuration)
3. ✅ Upload to TestFlight
4. ✅ Available for internal testers immediately

### Deploy to TestFlight (External Testing)

```bash
fastlane beta_external
```

Additional features:
- ✅ Waits for build processing to complete
- ✅ Distributes to external testers
- ✅ Sends notification emails to testers

### Deploy to App Store

```bash
fastlane release
```

This will:
1. ✅ Validate metadata
2. ✅ Increment build number
3. ✅ Build the app
4. ✅ Upload binary, metadata, and screenshots
5. ⏸️ Does NOT submit for review (you control when to submit)

## 📋 Available Lanes

### `beta` - TestFlight Internal Testing

```bash
fastlane beta
```

**What it does:**
- Builds app with `Zunlo` scheme (production)
- Increments build number
- Uploads to TestFlight
- Skips waiting for processing (faster)
- Available to internal testers only

**Best for:**
- Quick internal testing
- Development team testing
- Daily/frequent builds

### `beta_external` - TestFlight External Testing

```bash
fastlane beta_external
```

**What it does:**
- Same as `beta` but:
  - Waits for build processing
  - Distributes to external testers
  - Sends email notifications
  - Includes changelog: "Bug fixes and improvements"

**Best for:**
- Beta testers outside your organization
- Larger testing groups
- Pre-release candidates

**Note:** External testing requires Apple's approval for the first build.

### `release` - App Store Submission

```bash
fastlane release
```

**What it does:**
- Validates all metadata files
- Increments build number
- Builds the app
- Uploads binary
- Uploads metadata and screenshots
- Does NOT auto-submit for review

**Best for:**
- Production releases
- App Store submissions
- Major version updates

**After running:** Go to App Store Connect to submit for review manually.

## 🔧 Prerequisites

### 1. App Store Connect API Key

Ensure you have the API key configured:

```bash
export APP_STORE_CONNECT_API_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.fastlane/api_keys/AuthKey_XXXXXXXXXX.p8"
```

See `API_KEY_SETUP.md` for detailed setup instructions.

### 2. Code Signing

Ensure you have valid:
- ✅ Distribution certificate
- ✅ App Store provisioning profile
- ✅ Proper code signing configuration in Xcode

### 3. Metadata (for `release` lane)

Before running `release`, ensure metadata is ready:

```bash
fastlane validate_metadata
```

## 📱 Build Configuration

All lanes use:
- **Scheme:** `Zunlo` (production)
- **Configuration:** Release
- **Export Method:** app-store
- **Bundle ID:** `net.loginode.zunloapp`
- **Output:** `./build/Zunlo.ipa`

## 🔢 Build Number Management

Build numbers are automatically incremented before each build. The lanes use:

```ruby
increment_build_number(
  xcodeproj: "Zunlo.xcodeproj"
)
```

This ensures each upload has a unique build number.

### Manual Build Number Control

To set a specific build number:

```bash
fastlane run increment_build_number build_number:42
```

## 🧪 Testing Workflow

Recommended workflow:

1. **Development Testing**
   ```bash
   fastlane test
   ```

2. **Internal Beta Testing**
   ```bash
   fastlane beta
   ```

3. **External Beta Testing**
   ```bash
   fastlane beta_external
   ```

4. **Production Release**
   ```bash
   fastlane release
   ```

## 📊 Using the Helper Scripts

For easier execution with logging:

```bash
# TestFlight (logs to logs/fastlane/beta_TIMESTAMP.log)
./scripts/fl_beta.sh

# App Store (logs to logs/fastlane/release_TIMESTAMP.log)
./scripts/fl_release.sh
```

## 🔐 Security Best Practices

1. **Never commit:**
   - API keys
   - Certificates
   - Provisioning profiles
   - Build artifacts (*.ipa)

2. **Gitignore already configured for:**
   - `build/` directory
   - `*.ipa` files
   - Fastlane certificates

3. **Use environment variables** for sensitive data

## 🐛 Troubleshooting

### Build Fails

**Check:**
- ✅ Xcode scheme "Zunlo" exists and is shared
- ✅ Code signing is configured correctly
- ✅ All dependencies are installed

### Upload Fails

**Check:**
- ✅ API key is valid and has proper permissions
- ✅ Bundle ID matches App Store Connect
- ✅ Build number hasn't been used before

### Processing Takes Too Long

For `beta_external`, processing can take 10-30 minutes. Use `beta` instead for faster feedback.

### Metadata Validation Errors

Run validation first:
```bash
fastlane validate_metadata
```

Fix any errors before running `release`.

## 📱 TestFlight Management

### Adding Internal Testers

1. Go to App Store Connect
2. Navigate to TestFlight
3. Add testers to "App Store Connect Users" group
4. They'll receive builds automatically

### Adding External Testers

1. First build requires Apple review
2. Create external testing group
3. Add testers via email
4. Run `fastlane beta_external`
5. Testers receive email when build is approved

### Managing Builds

- Internal builds: Available immediately
- External builds: Available after Apple approval (~24 hours)
- You can have up to 100 active builds
- Builds expire after 90 days

## 🚀 Advanced Usage

### Custom Changelog for External Testing

Edit the `beta_external` lane in `fastlane/Fastfile`:

```ruby
upload_to_testflight(
  api_key: configure_api_key,
  changelog: "Your custom changelog here"
)
```

### Skip Build Number Increment

Remove or comment out:
```ruby
# increment_build_number(
#   xcodeproj: "Zunlo.xcodeproj"
# )
```

### Auto-Submit for Review

⚠️ **Not recommended** - but if you want auto-submit:

```ruby
deliver(
  submit_for_review: true,
  automatic_release: true  # or false for manual release
)
```

## 📚 Related Documentation

- **API Key Setup:** `API_KEY_SETUP.md`
- **Metadata Management:** `METADATA_GUIDE.md`
- **Screenshot Guide:** `README.md` (main fastlane docs)
- **Scripts:** `../scripts/README.md`

## 🔗 Useful Links

- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Fastlane Docs - TestFlight](https://docs.fastlane.tools/actions/testflight/)
- [Fastlane Docs - Deliver](https://docs.fastlane.tools/actions/deliver/)
