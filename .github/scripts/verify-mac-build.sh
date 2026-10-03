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

/usr/bin/python3 -B - "$resources_path" <<'PY'
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location("localizations", "scripts/package-localizations.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
repo = Path.cwd()
resources = Path(sys.argv[1])
catalog = module.validated_resources(repo)
expected_json = {f"{locale}.json" for locale in catalog}
expected_lproj = {f"{resource['bundle_localization']}.lproj" for resource in catalog.values()}
assert {file.name for file in (resources / "src/localizations").glob("*.json")} == expected_json, "Bundled JSON locale set differs from source"
assert {directory.name for directory in resources.glob("*.lproj")} == expected_lproj, "Bundled localization directories differ from source"
for locale, resource in catalog.items():
    source = repo / "src/localizations" / f"{locale}.json"
    packaged = resources / "src/localizations" / f"{locale}.json"
    assert packaged.read_bytes() == source.read_bytes(), f"{locale}: bundled translation differs from source"
    localization = f"{resource['bundle_localization']}.lproj/InfoPlist.strings"
    assert (resources / localization).read_bytes() == (repo / "macos" / localization).read_bytes(), f"{locale}: bundled InfoPlist strings differ from source"
print("Verified paired localization resources: " + ", ".join(sorted(catalog)))
PY

for localization in "$resources_path"/*.lproj; do
  plutil -lint "$localization/InfoPlist.strings"
done

printf '%s\n' 'Verified Universal binary, macOS 13.0 deployment target and bundled resources.'
