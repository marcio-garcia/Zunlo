fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate screenshots

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

### ios test_all_devices

```sh
[bundle exec] fastlane ios test_all_devices
```

Run tests on all devices

### ios build_for_testing

```sh
[bundle exec] fastlane ios build_for_testing
```

Build for testing

### ios screenshots_and_upload

```sh
[bundle exec] fastlane ios screenshots_and_upload
```

Generate screenshots and upload to App Store Connect

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload metadata to App Store Connect

### ios fix_screenshots

```sh
[bundle exec] fastlane ios fix_screenshots
```

Fix existing screenshot dimensions

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots to App Store Connect

### ios validate_metadata

```sh
[bundle exec] fastlane ios validate_metadata
```

Validate metadata locally

### ios preview_metadata

```sh
[bundle exec] fastlane ios preview_metadata
```

Preview metadata without uploading

### ios verify_metadata_remote

```sh
[bundle exec] fastlane ios verify_metadata_remote
```

Verify metadata with App Store Connect (requires authentication)

### ios prepare_app_store

```sh
[bundle exec] fastlane ios prepare_app_store
```

Complete App Store preparation (screenshots + metadata)

### ios upload_metadata_prod

```sh
[bundle exec] fastlane ios upload_metadata_prod
```

Upload metadata for production

### ios upload_metadata_staging

```sh
[bundle exec] fastlane ios upload_metadata_staging
```

Upload metadata for staging

### ios upload_metadata_dev

```sh
[bundle exec] fastlane ios upload_metadata_dev
```

Upload metadata for development

### ios screenshots_env

```sh
[bundle exec] fastlane ios screenshots_env
```

Generate screenshots for specific environment

### ios setup_match

```sh
[bundle exec] fastlane ios setup_match
```

Setup Match - Generate certificates and provisioning profiles

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios beta_external

```sh
[bundle exec] fastlane ios beta_external
```

Build and upload to TestFlight with external testing

### ios release

```sh
[bundle exec] fastlane ios release
```

Build for App Store submission

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
