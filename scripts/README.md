# Fastlane Scripts

This directory contains wrapper scripts for fastlane lanes that automatically configure the environment and save output to log files.

## Usage

Each script accepts an environment argument and saves output to a timestamped log file in `logs/fastlane/`:

```bash
# Run with default environment (prod for most lanes, dev for tests)
./scripts/fl_validate_metadata.sh

# Run with specific environment
./scripts/fl_validate_metadata.sh staging
./scripts/fl_validate_metadata.sh dev
./scripts/fl_validate_metadata.sh prod
```

## Available Scripts

### Metadata Management
- **`fl_validate_metadata.sh`** - Validate metadata files locally without uploading
- **`fl_preview_metadata.sh`** - Preview metadata configuration without uploading
- **`fl_verify_metadata_remote.sh`** - Verify and upload metadata to App Store Connect (requires authentication)
- **`fl_upload_metadata.sh`** - Upload metadata to App Store Connect

### Screenshots
- **`fl_screenshots.sh`** - Generate screenshots for the app
- **`fl_upload_screenshots.sh`** - Upload screenshots to App Store Connect
- **`fl_screenshots_and_upload.sh`** - Generate screenshots and upload to App Store Connect

### Complete Preparation
- **`fl_prepare_app_store.sh`** - Complete App Store preparation (screenshots + metadata)

### Testing
- **`fl_test.sh`** - Run tests on a single device
- **`fl_test_all_devices.sh`** - Run tests on all configured devices
- **`fl_build_for_testing.sh`** - Build the app for testing

## Features

Each script:
- ✅ Accepts environment as argument (prod, staging, dev)
- ✅ Sources the environment configuration script automatically
- ✅ Displays output in real-time
- ✅ Saves complete output to timestamped log file
- ✅ Shows log file location at the start
- ✅ Waits for user to press Enter before closing
- ✅ Preserves exit code from fastlane

## Log Files

Log files are saved to: `~/dev/loginode/Zunlo/logs/fastlane/`

Format: `{lane_name}_{environment}_{timestamp}.log`

Example: `verify_metadata_remote_prod_20250930_173045.log`

## Examples

```bash
# Validate metadata for production
./scripts/fl_validate_metadata.sh prod

# Run tests in development
./scripts/fl_test.sh dev

# Upload metadata to staging
./scripts/fl_upload_metadata.sh staging

# Verify metadata with remote (production)
./scripts/fl_verify_metadata_remote.sh prod
```

## Environment Configuration

The scripts automatically source `fastlane/scripts/set_env.sh` which configures:
- `APP_BUNDLE_ID` - The bundle identifier for the environment
- `SCHEME` - The Xcode scheme to use
- `APP_STORE_CONNECT_API_KEY_*` - API credentials (from your shell profile)

### Environment Values

| Environment | Bundle ID | Scheme |
|------------|-----------|--------|
| prod | net.loginode.zunloapp | Zunlo |
| staging | net.loginode.zunloapp.stg | Zunlo - staging |
| dev | net.loginode.zunloapp.dev | Zunlo - debug |

## Troubleshooting

### Script won't run
Make sure the script is executable:
```bash
chmod +x scripts/fl_*.sh
```

### API Key issues
Ensure your API key environment variables are set in your shell profile (~/.zshrc or ~/.bash_profile):
```bash
export APP_STORE_CONNECT_API_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.fastlane/api_keys/AuthKey_XXXXXXXXXX.p8"
```

### View recent logs
```bash
# List recent log files
ls -lt ~/dev/loginode/Zunlo/logs/fastlane/ | head

# View a specific log
cat ~/dev/loginode/Zunlo/logs/fastlane/verify_metadata_remote_prod_20250930_173045.log
```
