# Script Consolidation Guide

## ✨ New Unified Script: `fl`

All 13 individual scripts have been consolidated into a single, unified script: `./scripts/fl`

### Usage

```bash
./scripts/fl <lane> [environment]
```

### Benefits

✅ **Single script to maintain** - Instead of 13 separate files
✅ **Consistent behavior** - Same logging, error handling across all lanes
✅ **Auto-detects defaults** - Knows which environment to use for each lane
✅ **Easy to use** - Less to remember, clearer syntax
✅ **Built-in help** - Run without arguments to see all available lanes

## 📋 Migration Guide

### Old Scripts → New Unified Script

**Metadata Operations:**
```bash
# Old way
./scripts/fl_validate_metadata.sh prod
./scripts/fl_preview_metadata.sh staging
./scripts/fl_upload_metadata.sh prod
./scripts/fl_verify_metadata_remote.sh prod

# New way
./scripts/fl validate_metadata prod
./scripts/fl preview_metadata staging
./scripts/fl upload_metadata prod
./scripts/fl verify_metadata_remote prod

# Even simpler (uses default: prod)
./scripts/fl validate_metadata
./scripts/fl upload_metadata
```

**Screenshot Operations:**
```bash
# Old way
./scripts/fl_screenshots.sh dev
./scripts/fl_upload_screenshots.sh prod
./scripts/fl_screenshots_and_upload.sh prod

# New way
./scripts/fl screenshots dev
./scripts/fl upload_screenshots prod
./scripts/fl screenshots_and_upload prod

# Simpler (uses default: prod)
./scripts/fl screenshots
./scripts/fl upload_screenshots
```

**Testing Operations:**
```bash
# Old way
./scripts/fl_test.sh dev
./scripts/fl_test_all_devices.sh dev
./scripts/fl_build_for_testing.sh dev

# New way
./scripts/fl test dev
./scripts/fl test_all_devices dev
./scripts/fl build_for_testing dev

# Simpler (uses default: dev)
./scripts/fl test
./scripts/fl test_all_devices
```

**Deployment Operations:**
```bash
# Old way
./scripts/fl_beta.sh
./scripts/fl_release.sh
./scripts/fl_prepare_app_store.sh

# New way (exactly the same)
./scripts/fl beta
./scripts/fl release
./scripts/fl prepare_app_store
```

## 🎯 Quick Reference

### Common Commands

```bash
# Show help (list all lanes)
./scripts/fl

# Metadata
./scripts/fl validate_metadata          # Validate for production
./scripts/fl upload_metadata staging    # Upload to staging
./scripts/fl upload_metadata_prod       # Upload to production (shortcut)
./scripts/fl verify_metadata_remote     # Verify with App Store Connect

# Screenshots
./scripts/fl screenshots                # Generate for production
./scripts/fl upload_screenshots         # Upload to production
./scripts/fl fix_screenshots            # Fix screenshot dimensions
./scripts/fl screenshots_and_upload     # Generate and upload in one step

# Complete Workflows
./scripts/fl prepare_app_store          # Full preparation (screenshots + metadata)

# Testing
./scripts/fl test                       # Test in dev
./scripts/fl test_all_devices          # Test all devices in dev
./scripts/fl build_for_testing         # Build for testing

# Deployment
./scripts/fl beta                       # TestFlight upload (internal)
./scripts/fl beta_external              # TestFlight upload (external testers)
./scripts/fl release                    # App Store upload
```

## 🔍 Environment Defaults

The script automatically chooses the right default environment:

| Lane Type | Default Environment |
|-----------|-------------------|
| Metadata operations | `prod` |
| Screenshot operations | `prod` |
| Testing operations | `dev` |
| Deployment operations | Always production (no env arg) |

You can always override the default by specifying the environment:
```bash
./scripts/fl screenshots dev
./scripts/fl test prod
```

## 📊 Comparison

**Before (13 separate scripts):**
```
scripts/
├── fl_beta.sh
├── fl_build_for_testing.sh
├── fl_prepare_app_store.sh
├── fl_preview_metadata.sh
├── fl_release.sh
├── fl_screenshots.sh
├── fl_screenshots_and_upload.sh
├── fl_test.sh
├── fl_test_all_devices.sh
├── fl_upload_metadata.sh
├── fl_upload_screenshots.sh
├── fl_validate_metadata.sh
└── fl_verify_metadata_remote.sh
```

**After (1 unified script):**
```
scripts/
└── fl   # Handles all 13+ lanes
```

## 🚀 Advanced Usage

### Custom Lanes

The unified script works with any fastlane lane:

```bash
./scripts/fl <any_lane_name> [environment]
```

### Log Files

Logs are automatically saved with appropriate names:

```bash
# With environment
./scripts/fl test dev
# Creates: logs/fastlane/test_dev_20250101_120000.log

# Without environment
./scripts/fl beta
# Creates: logs/fastlane/beta_20250101_120000.log
```

## ⚠️ Breaking Changes

**None!** The old scripts still exist and work. You can:
1. Start using `./scripts/fl` for new workflows
2. Gradually migrate existing scripts/automation
3. Eventually delete old individual scripts when comfortable

## 🗑️ Optional Cleanup

Once you're comfortable with the unified script, you can remove the old scripts:

```bash
# Backup first (optional)
mkdir -p scripts/legacy
mv scripts/fl_*.sh scripts/legacy/

# Or delete them
rm scripts/fl_*.sh
```

**Keep these:**
- `scripts/fl` - The unified script
- `scripts/README.md` - Documentation
- Any non-fastlane scripts

## 📝 Examples

### Daily Development Workflow

```bash
# Validate changes
./scripts/fl validate_metadata

# Generate screenshots
./scripts/fl screenshots

# Run tests
./scripts/fl test

# Upload to TestFlight
./scripts/fl beta
```

### Multi-Environment Testing

```bash
# Test all environments
./scripts/fl test dev
./scripts/fl test staging
./scripts/fl test prod

# Upload metadata to each
./scripts/fl upload_metadata dev
./scripts/fl upload_metadata staging
./scripts/fl upload_metadata prod
```

### Release Workflow

```bash
# Validate everything
./scripts/fl validate_metadata

# Generate fresh screenshots
./scripts/fl screenshots

# Full App Store preparation
./scripts/fl prepare_app_store

# Or just build and release
./scripts/fl release
```

## 🤝 Feedback

The unified script should handle all use cases. If you encounter issues or need additional features, the script is easy to extend in `scripts/fl`.
