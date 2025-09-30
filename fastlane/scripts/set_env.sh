#!/bin/bash

# Environment configuration script for Zunlo fastlane

set -e

ENVIRONMENT=${1:-prod}

case $ENVIRONMENT in
  "prod"|"production")
    export APP_BUNDLE_ID="net.loginode.zunloapp"
    export SCHEME="Zunlo"
    echo "🚀 Configured for PRODUCTION"
    echo "   Bundle ID: $APP_BUNDLE_ID"
    echo "   Scheme: $SCHEME"
    ;;
  "staging"|"stage"|"stg")
    export APP_BUNDLE_ID="net.loginode.zunloapp.stg"
    export SCHEME="Zunlo - staging"
    echo "🧪 Configured for STAGING"
    echo "   Bundle ID: $APP_BUNDLE_ID"
    echo "   Scheme: $SCHEME"
    ;;
  "dev"|"development"|"debug")
    export APP_BUNDLE_ID="net.loginode.zunloapp.dev"
    export SCHEME="Zunlo - debug"
    echo "🔧 Configured for DEVELOPMENT"
    echo "   Bundle ID: $APP_BUNDLE_ID"
    echo "   Scheme: $SCHEME"
    ;;
  *)
    echo "❌ Unknown environment: $ENVIRONMENT"
    echo "Usage: source set_env.sh [prod|staging|stg|dev]"
    exit 1
    ;;
esac

echo ""
echo "Environment variables set. You can now run fastlane commands."
echo "Example: fastlane upload_metadata"
echo ""

# Check for API key configuration
if [ -n "$APP_STORE_CONNECT_API_KEY_ID" ] && [ -n "$APP_STORE_CONNECT_ISSUER_ID" ]; then
  echo "✅ App Store Connect API Key configured"
  if [ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
    echo "✅ API Key file found"
  else
    echo "⚠️  API Key file not found at: $APP_STORE_CONNECT_API_KEY_PATH"
  fi
else
  echo "ℹ️  For MFA accounts, set up App Store Connect API Key:"
  echo "   See: fastlane/API_KEY_SETUP.md"
fi