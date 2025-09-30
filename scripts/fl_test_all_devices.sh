#!/bin/bash

# Fastlane: test_all_devices
# Run tests on all configured devices

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_ARG="${1:-dev}"

# Create logs directory if it doesn't exist
mkdir -p "$PROJECT_DIR/logs/fastlane"

# Generate log filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$PROJECT_DIR/logs/fastlane/test_all_devices_${ENV_ARG}_${TIMESTAMP}.log"

echo "===========================================" | tee "$LOG_FILE"
echo "Fastlane Lane: test_all_devices" | tee -a "$LOG_FILE"
echo "Environment: $ENV_ARG" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "===========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Source environment configuration
source "$PROJECT_DIR/fastlane/scripts/set_env.sh" "$ENV_ARG" 2>&1 | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run fastlane lane
cd "$PROJECT_DIR" && fastlane test_all_devices 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "" | tee -a "$LOG_FILE"
echo "===========================================" | tee -a "$LOG_FILE"
echo "Fastlane completed with exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
echo "===========================================" | tee -a "$LOG_FILE"

# Keep terminal open
echo ""
read -p "Press Enter to close..."

exit $EXIT_CODE
