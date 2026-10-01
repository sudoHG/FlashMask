#!/usr/bin/env bash
set -euo pipefail

# Run from the repository root after ./build.sh. No app is launched or signed.
app_path=${1:-'.derivedData/build/Build/Products/Release/Flash Mask.app'}
plist_path="$app_path/Contents/Info.plist"
resources_path="$app_path/Contents/Resources"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$plist_path"
}

[[ "$(plist_value CFBundleIdentifier)" == 'com.331workc.flashmask' ]] || fail 'Unexpected Bundle ID'
[[ "$(plist_value LSMinimumSystemVersion)" == '13.0' ]] || fail 'Expected minimum macOS 13.0'
executable_path="$app_path/Contents/MacOS/$(plist_value CFBundleExecutable)"

for architecture in arm64 x86_64; do
  lipo "$executable_path" -verify_arch "$architecture"
  build_info=$(xcrun vtool -arch "$architecture" -show-build "$executable_path")
  printf '%s\n' "$build_info"
  minimum_os=$(awk '$1 == "minos" { print $2 }' <<< "$build_info")
  [[ "$minimum_os" == '13.0' ]] || fail "$architecture does not target macOS 13.0"
done

for resource in index.html src/flash-mask-contract.js src/selection-lasso-cleaner.js assets/FlashMask-Mark.svg; do
  cmp "$resource" "$resources_path/$resource"
done
cmp macos/FlashMask.icns "$resources_path/FlashMask.icns"

for language in en zh-Hans; do
  plutil -lint "$resources_path/$language.lproj/InfoPlist.strings"
done

printf '%s\n' 'Verified Universal binary, macOS 13.0 deployment target and bundled resources.'
