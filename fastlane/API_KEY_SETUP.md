# App Store Connect API Key Setup

Since your Apple ID has MFA enabled, using an App Store Connect API Key is the most reliable method for fastlane automation.

## 📋 Steps to Create API Key

### 1. Access App Store Connect
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple ID (marcio@loginode.net)
3. Complete MFA if prompted

### 2. Create API Key
1. Navigate to **Users and Access** → **Integrations** → **App Store Connect API**
2. Click **Generate API Key**
3. Fill in the details:
   - **Name**: `Zunlo Fastlane API Key`
   - **Access**: `Developer` (or `Admin` if you need full access)
   - **App Access**: Select your apps or choose "All Apps"

### 3. Download and Save Key
1. **Download the .p8 file** (you can only do this once!)
2. **Copy the Key ID** (something like `XXXXXXXXXX`)
3. **Note the Issuer ID** (found at the top of the API Keys page)

### 4. Secure Storage
```bash
# Create secure directory for API keys
mkdir -p ~/.fastlane/api_keys
chmod 700 ~/.fastlane/api_keys

# Move your downloaded key file
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.fastlane/api_keys/
chmod 600 ~/.fastlane/api_keys/AuthKey_XXXXXXXXXX.p8
```

## ⚙️ Configuration Options

### Option A: Environment Variables (Recommended)
Add to your shell profile (~/.zshrc or ~/.bash_profile):

```bash
# App Store Connect API Configuration
export APP_STORE_CONNECT_API_KEY_ID="XXXXXXXXXX"        # Your Key ID
export APP_STORE_CONNECT_ISSUER_ID="YYYYYY-YYYY-YYYY"   # Your Issuer ID
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.fastlane/api_keys/AuthKey_XXXXXXXXXX.p8"
```

### Option B: Direct File Path
Uncomment and update in `Deliverfile`:
```ruby
api_key_path("~/.fastlane/api_keys/AuthKey_XXXXXXXXXX.p8")
```

## 🔐 Security Best Practices

1. **Never commit API keys to git**
   - Add to `.gitignore`: `AuthKey_*.p8`
   - Use environment variables for sensitive data

2. **Limit API key permissions**
   - Use "Developer" access unless you need full admin rights
   - Scope to specific apps when possible

3. **Rotate keys periodically**
   - API keys don't expire but should be rotated for security

## ✅ Verification

After setup, test with:
```bash
# Set environment and test
source fastlane/scripts/set_env.sh prod
fastlane verify_metadata_remote
```

## 🆘 Troubleshooting

### Common Issues:
- **"Invalid API Key"**: Check Key ID and Issuer ID are correct
- **"Permission denied"**: Ensure API key has proper app access
- **"File not found"**: Verify .p8 file path is correct

### Debug Commands:
```bash
# Check environment variables
echo $APP_STORE_CONNECT_API_KEY_ID
echo $APP_STORE_CONNECT_ISSUER_ID
echo $APP_STORE_CONNECT_API_KEY_PATH

# Verify file exists and has correct permissions
ls -la ~/.fastlane/api_keys/
```

## 🔄 Alternative: Session-Based Auth

If you prefer not to use API keys, fastlane supports MFA with session storage:

```bash
# First time - will prompt for MFA
FASTLANE_SESSION=$(fastlane spaceauth -u marcio@loginode.net)

# Save session for reuse
export FASTLANE_SESSION="your_session_string_here"
```

Note: Sessions expire and need renewal, making API keys more reliable for automation.