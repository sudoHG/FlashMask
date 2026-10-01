#!/bin/sh
# Build an unsigned Universal local app, optionally package a local-test DMG,
# or package an already notarized app without rebuilding or resigning it.
#
# Usage:
#   ./build.sh
#   ./build.sh --dmg
#   ./build.sh --version 1.2 --build-number 42 --dmg
#   ./build.sh --package-app "/path/to/stapled/Flash Mask.app"
set -eu

PROJECT='macos/Flash Mask.xcodeproj'
SCHEME='Flash Mask'
CONFIGURATION='Release'
DERIVED='.derivedData/build'
VERSION='1.2'
BUILD_NUMBER='7'
MAKE_DMG=0
PACKAGE_APP=''
VERSION_WAS_SET=0
BUILD_NUMBER_WAS_SET=0

usage() {
  cat <<'USAGE'
Build an unsigned Universal (arm64 + x86_64) local app targeting macOS 13.0.

Usage:
  ./build.sh [--dmg] [--version VERSION] [--build-number NUMBER]
  ./build.sh --package-app "/path/to/stapled/Flash Mask.app"

Options:
  --dmg                  Also create an unsigned DMG for local testing.
  --version VERSION      Override CFBundleShortVersionString (default: 1.2).
  --build-number NUMBER  Override CFBundleVersion (default: 7).
  --package-app PATH     Verify and package an existing notarized Universal app.
  -h, --help             Show this help.

This script does not sign, notarize, archive, or produce an App Store build.
USAGE
}

fail() {
  printf '%s\n' "Error: $*" >&2
  exit 1
}

require_value() {
  [ "$#" -ge 2 ] || fail "Missing value for $1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dmg)
      MAKE_DMG=1
      shift
      ;;
    --version)
      require_value "$@"
      VERSION=$2
      VERSION_WAS_SET=1
      shift 2
      ;;
    --build-number)
      require_value "$@"
      BUILD_NUMBER=$2
      BUILD_NUMBER_WAS_SET=1
      shift 2
      ;;
    --package-app)
      require_value "$@"
      [ -z "$PACKAGE_APP" ] || fail '--package-app may only be specified once'
      PACKAGE_APP=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1 (see --help)"
      ;;
  esac
done

validate_version() {
  case "$1" in
    ''|*[!0-9.]* ) fail "Invalid version: $1" ;;
  esac
}

validate_build_number() {
  case "$1" in
    ''|*[!0-9.]* ) fail "Invalid build number: $1" ;;
  esac
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

read_app_metadata() {
  APP_INFO="$APP_PATH/Contents/Info.plist"
  [ -f "$APP_INFO" ] || fail "Missing app Info.plist: $APP_INFO"
  APP_VERSION=$(plist_value "$APP_INFO" CFBundleShortVersionString) || fail 'Cannot read app version'
  APP_BUILD=$(plist_value "$APP_INFO" CFBundleVersion) || fail 'Cannot read app build number'
  APP_MINIMUM_OS=$(plist_value "$APP_INFO" LSMinimumSystemVersion) || fail 'Cannot read minimum macOS version'
  APP_EXECUTABLE=$(plist_value "$APP_INFO" CFBundleExecutable) || fail 'Cannot read app executable name'

  validate_version "$APP_VERSION"
  validate_build_number "$APP_BUILD"
  [ "$APP_MINIMUM_OS" = '13.0' ] || fail "Expected minimum macOS 13.0, found $APP_MINIMUM_OS"
  APP_EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_EXECUTABLE"
  [ -f "$APP_EXECUTABLE_PATH" ] || fail "Missing app executable: $APP_EXECUTABLE_PATH"
  lipo "$APP_EXECUTABLE_PATH" -verify_arch arm64 || fail 'App is missing the arm64 slice'
  lipo "$APP_EXECUTABLE_PATH" -verify_arch x86_64 || fail 'App is missing the x86_64 slice'
}

verify_notarized_signature() {
  codesign --verify --deep --strict --verbose=2 "$APP_PATH" || fail 'Code signature verification failed'
  SIGNATURE_INFO=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1) || fail 'Cannot read code signature details'
  printf '%s\n' "$SIGNATURE_INFO" | grep -q '^Authority=Developer ID Application:' || fail 'App is not signed with a Developer ID Application identity'
  SIGNATURE_TIMESTAMP=$(printf '%s\n' "$SIGNATURE_INFO" | sed -n 's/^Timestamp=//p' | sed -n '1p')
  [ -n "$SIGNATURE_TIMESTAMP" ] && [ "$SIGNATURE_TIMESTAMP" != 'none' ] || fail 'App signature has no secure timestamp'
  xcrun stapler validate "$APP_PATH" || fail 'Notarization ticket validation failed'
}

create_dmg() {
  APP_NAME=$(basename "$APP_PATH")
  DMG_NAME="FlashMask-${APP_VERSION}-b${APP_BUILD}-Universal.dmg"
  DMG_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/flashmask-dmg.XXXXXX")
  trap 'rm -rf "$DMG_ROOT"' 0
  printf '\n%s\n' "==> Creating DMG: $DMG_NAME"
  cp -R "$APP_PATH" "$DMG_ROOT/$APP_NAME"
  ln -sfn /Applications "$DMG_ROOT/Applications"
  hdiutil create -volname 'Flash Mask' -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_NAME" >/dev/null
  rm -rf "$DMG_ROOT"
  trap - 0
  printf '%s\n' "==> DMG: $(pwd)/$DMG_NAME"
}

if [ -n "$PACKAGE_APP" ]; then
  [ "$MAKE_DMG" -eq 0 ] || fail '--package-app already creates a DMG; do not combine it with --dmg'
  [ "$VERSION_WAS_SET" -eq 0 ] || fail 'Version overrides cannot be used with --package-app'
  [ "$BUILD_NUMBER_WAS_SET" -eq 0 ] || fail 'Build-number overrides cannot be used with --package-app'
  case "$PACKAGE_APP" in
    *.app) ;;
    *) fail '--package-app must point to an .app bundle' ;;
  esac
  [ -d "$PACKAGE_APP" ] || fail "App bundle not found: $PACKAGE_APP"
  APP_PATH=$(cd "$(dirname "$PACKAGE_APP")" && pwd)/$(basename "$PACKAGE_APP")
  read_app_metadata
  verify_notarized_signature
  printf '%s\n' '==> Packaging the existing stapled app only; no build or signing will run.'
  create_dmg
  exit 0
fi

validate_version "$VERSION"
validate_build_number "$BUILD_NUMBER"

printf '%s\n' "==> Building unsigned Universal (arm64 + x86_64) $CONFIGURATION app for macOS 13.0+..."
set -- xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" "$@"
APP_PATH="$DERIVED/Build/Products/$CONFIGURATION/Flash Mask.app"
[ -d "$APP_PATH" ] || fail "Build did not produce app bundle: $APP_PATH"
read_app_metadata
[ "$APP_VERSION" = "$VERSION" ] || fail "Expected version $VERSION, found $APP_VERSION"
[ "$APP_BUILD" = "$BUILD_NUMBER" ] || fail "Expected build $BUILD_NUMBER, found $APP_BUILD"
printf '%s\n' "==> App: $APP_PATH"
file "$APP_EXECUTABLE_PATH"

if [ "$MAKE_DMG" -eq 1 ]; then
  printf '%s\n' '==> This unsigned DMG is for local testing, not Gatekeeper distribution.'
  create_dmg
fi
