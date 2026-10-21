#!/bin/bash
set -euo pipefail
# 0.1.9: reliable drag hover, per-app exclusions and two-second notch dismissal.
cd "$(dirname "$0")/.."

app="$PWD/dist/Convert w Blueberry.app"
module_cache="$PWD/.build/module-cache"
mkdir -p "$app/Contents/MacOS" "$module_cache"

# Check the Swift compiler/SDK pair before compiling the full application.
# This avoids a long stream of cascading AppKit/Foundation diagnostics when
# Command Line Tools and the macOS SDK come from different Apple releases.
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/blueberry-toolchain-check.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT
cat > "$tmpdir/toolchain-check.swift" <<'SWIFT'
import AppKit
print("AppKit toolchain check passed")
SWIFT

compiler_version="$(xcrun swift --version 2>&1 | head -n 1 || true)"
sdk_root="$(xcode-select -p 2>/dev/null || true)"
compatible_sdk=""

# Prefer the active SDK, then try the installed SDKs from newest to oldest.
sdk_candidates=()
active_sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [[ -n "$active_sdk" && -d "$active_sdk" ]]; then
  sdk_candidates+=("$active_sdk")
fi
for candidate in /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk \
                 /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk; do
  [[ -d "$candidate" ]] || continue
  already_added=false
  for existing in "${sdk_candidates[@]}"; do
    [[ "$existing" == "$candidate" ]] && already_added=true && break
  done
  [[ "$already_added" == true ]] || sdk_candidates+=("$candidate")
done

for candidate in "${sdk_candidates[@]}"; do
  if xcrun swiftc -sdk "$candidate" \
      -target arm64-apple-macosx26.0 \
      -module-cache-path "$module_cache" \
      "$tmpdir/toolchain-check.swift" -o "$tmpdir/toolchain-check" \
      >"$tmpdir/check.log" 2>&1; then
    compatible_sdk="$candidate"
    break
  fi
done

if [[ -z "$compatible_sdk" ]]; then
  echo >&2
  echo "ERROR: No compatible Swift compiler + macOS SDK pair was found." >&2
  echo "The app was not compiled. This is an Apple toolchain mismatch, not yet an app-source error." >&2
  echo >&2
  echo "Swift compiler:" >&2
  echo "  $compiler_version" >&2
  echo "Active developer directory:" >&2
  echo "  ${sdk_root:-unknown}" >&2
  echo "SDKs checked:" >&2
  if [[ ${#sdk_candidates[@]} -eq 0 ]]; then
    echo "  (No SDKs found)" >&2
  else
    printf '  %s\n' "${sdk_candidates[@]}" >&2
  fi
  echo >&2
  echo "Fix: install/select an Apple Xcode or Command Line Tools release whose Swift compiler" >&2
  echo "matches its macOS SDK. Then rerun ./scripts/build-app.sh." >&2
  echo "Do not copy SDKs between Xcode versions or delete the existing developer tools." >&2
  if [[ -s "$tmpdir/check.log" ]]; then
    echo >&2
    echo "Last compatibility-test message:" >&2
    tail -n 12 "$tmpdir/check.log" >&2
  fi
  exit 2
fi

echo "Using compatible SDK: $compatible_sdk"
echo "Compiling Convert w Blueberry…"
find NativeApp/Sources -name '*.swift' -print0 |
  xargs -0 xcrun swiftc \
    -sdk "$compatible_sdk" \
    -target arm64-apple-macosx26.0 \
    -swift-version 5 -O -parse-as-library \
    -module-cache-path "$module_cache" \
    -o "$app/Contents/MacOS/ConvertWithBlueberry"

# Preserve the legacy bundle identifier so existing settings and login registration survive.
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ConvertWithBlueberry</string>
<key>CFBundleIdentifier</key><string>com.syntaxerror.convertwblueberry</string>
<key>CFBundleName</key><string>Convert w Blueberry</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.9</string>
<key>CFBundleVersion</key><string>10</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
mkdir -p "$app/Contents/Resources"
rm -rf "$PWD/.build/AppIcon.iconset"
cp -R "$PWD/assets/Blueberry.iconset" "$PWD/.build/AppIcon.iconset"
python3 scripts/package-icon.py .build/AppIcon.iconset "$app/Contents/Resources/AppIcon.icns"
cp LICENSE "$app/Contents/Resources/GPL-3.0.txt"
cp NativeApp/LICENSE "$app/Contents/Resources/Satsuma-MIT.txt"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
# Developer trials use ad-hoc signing. Developer ID + notarization is required for trusted public distribution.
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --deep --strict --verbose=2 "$app"
test -x "$app/Contents/MacOS/ConvertWithBlueberry"
plutil -lint "$app/Contents/Info.plist"
printf 'Built %s\n' "$app"
