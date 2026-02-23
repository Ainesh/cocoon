#!/bin/bash
# =============================================================================
# Cocoon Test Coverage Report Generator
# =============================================================================
#
# Runs all unit and widget tests with coverage collection, generates an
# HTML report, and filters out generated/non-testable files.
#
# Prerequisites:
#   brew install lcov
#
# Usage:
#   chmod +x test/test_coverage.sh
#   ./test/test_coverage.sh
#
# Coverage Targets:
#   Models    >= 95%
#   Services  >= 85%
#   Utils     >= 95%
#   Widgets   >= 70%
#   Screens   >= 60%
#   Overall   >= 75%
# =============================================================================

set -e

echo "🧪 Running tests with coverage..."
flutter test --coverage

echo ""
echo "📊 Filtering generated files from coverage..."

# Check if lcov is installed
if ! command -v lcov &>/dev/null; then
  echo "⚠️  lcov not found. Install it with: brew install lcov"
  echo "📄 Raw coverage report available at: coverage/lcov.info"
  exit 0
fi

# Remove generated/non-testable files from the coverage report
lcov --remove coverage/lcov.info \
  'lib/firebase_options.dart' \
  'lib/generated/*' \
  -o coverage/lcov_filtered.info \
  --quiet

echo "📈 Generating HTML report..."
genhtml coverage/lcov_filtered.info \
  -o coverage/html \
  --quiet

echo ""
echo "✅ Coverage report generated!"
echo "   📂 Open: coverage/html/index.html"
echo ""

# Print summary
echo "📋 Coverage Summary:"
echo "-------------------------------------------"
lcov --summary coverage/lcov_filtered.info 2>&1 | grep -E "lines|functions|branches" || true
echo "-------------------------------------------"

# Try to open the report (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  open coverage/html/index.html 2>/dev/null || true
fi
