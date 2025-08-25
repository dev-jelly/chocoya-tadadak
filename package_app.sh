#!/usr/bin/env bash
set -euo pipefail

# Defaults (allow override via env or CLI)
ICON_SRC=${ICON_SRC:-"Sources/image.png"}
ICON_NAME=${ICON_NAME:-"AppIcon"}
BUNDLE_ID=${BUNDLE_ID:-"com.tadadak.app"}
SIGN=${SIGN:-0}
SIGN_IDENTITY=${SIGN_IDENTITY:-""}
ENTITLEMENTS=${ENTITLEMENTS:-""}
NOTARIZE=${NOTARIZE:-0}
APPLE_ID=${APPLE_ID:-""}
TEAM_ID=${TEAM_ID:-""}
APP_PASSWORD=${APP_PASSWORD:-""}
NOTARY_PROFILE=${NOTARY_PROFILE:-""}

# Parse CLI options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --icon-src)
      ICON_SRC="$2"; shift 2;;
    --icon-name)
      ICON_NAME="$2"; shift 2;;
    --bundle-id)
      BUNDLE_ID="$2"; shift 2;;
    --sign)
      SIGN=1; shift 1;;
    --identity)
      SIGN_IDENTITY="$2"; shift 2;;
    --entitlements)
      ENTITLEMENTS="$2"; shift 2;;
    --notarize)
      NOTARIZE=1; shift 1;;
    --apple-id)
      APPLE_ID="$2"; shift 2;;
    --team-id)
      TEAM_ID="$2"; shift 2;;
    --password)
      APP_PASSWORD="$2"; shift 2;;
    --notary-profile)
      NOTARY_PROFILE="$2"; shift 2;;
    --)
      shift; break;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--icon-src PATH] [--icon-name NAME] [--bundle-id ID] [--sign] [--identity CERT_NAME] [--entitlements PATH]" >&2
      exit 1;;
  esac
done

# Build release
swift build -c release

# Paths
PRODUCT_NAME="Tadadak"
BUILD_DIR=".build/release"
EXECUTABLE_PATH="$BUILD_DIR/$PRODUCT_NAME"
APP_DIR="dist/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PKGINFO="$CONTENTS_DIR/PkgInfo"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

# Clean
rm -rf "dist"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

# Copy resources from build bundle if present
if [ -d "$BUILD_DIR/$PRODUCT_NAME.bundle/Resources" ]; then
  rsync -a "$BUILD_DIR/$PRODUCT_NAME.bundle/Resources/" "$RESOURCES_DIR/"
fi

# If SPM resource bundle layout differs, copy from Sources
if [ -d "Sources/TadadakApp/Resources" ]; then
  rsync -a "Sources/TadadakApp/Resources/" "$RESOURCES_DIR/"
fi

# Compile asset catalog (e.g., MenuBarIcon) into Resources so status bar icon works after packaging
ASSET_DIR="Sources/TadadakApp/Assets.xcassets"
if [ -d "$ASSET_DIR" ]; then
  echo "Compiling asset catalog..."
  xcrun actool "$ASSET_DIR" --compile "$RESOURCES_DIR" --platform macosx \
    --minimum-deployment-target 13.0 --enable-on-demand-resources NO >/dev/null
fi

# Generate .icns app icon if available
ICONSET_DIR="$BUILD_DIR/${ICON_NAME}.iconset"
ICNS_PATH="$RESOURCES_DIR/${ICON_NAME}.icns"

if [ -f "$ICON_SRC" ]; then
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  # Generate required icon sizes
  sips -z 16 16  "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32  "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32  "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64  "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  # Build .icns and place into app Resources
  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
  else
  echo "warning: 'iconutil' not found; skipping .icns generation" >&2
  fi
else
  echo "warning: $ICON_SRC not found; skipping icon generation" >&2
fi

# Minimal Info.plist including icon reference
cat > "$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleName</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundleDisplayName</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundleIconFile</key>
	<string>$ICON_NAME</string>
	<key>CFBundleExecutable</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSMainNibFile</key>
	<string></string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

# PkgInfo (optional)
echo -n 'APPL????' > "$PKGINFO"

# Codesign if requested
if [[ "$SIGN" -eq 1 ]]; then
  echo "Signing app bundle..."
  if [[ -z "$SIGN_IDENTITY" ]]; then
    # Prefer a Developer ID Application identity for distribution
    DETECTED_ID=$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n1)
    if [[ -z "$DETECTED_ID" ]]; then
      # Fallback to Apple Development
      DETECTED_ID=$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -n1)
    fi
    if [[ -z "$DETECTED_ID" ]]; then
      echo "error: No code signing identities found in keychain" >&2
      exit 1
    fi
    SIGN_IDENTITY="$DETECTED_ID"
    echo "Using detected identity: $SIGN_IDENTITY"
  else
    echo "Using provided identity: $SIGN_IDENTITY"
  fi

  CODESIGN_ARGS=(--force --deep --options runtime --sign "$SIGN_IDENTITY")
  if [[ -n "$ENTITLEMENTS" ]]; then
    CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
  fi
  # Timestamp is recommended; if offline it may be skipped by codesign automatically
  CODESIGN_ARGS+=(--timestamp)

  /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"

  echo "Verifying signature..."
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"
  /usr/bin/codesign --display --verbose=2 "$APP_DIR" || true
fi

# Create a zip for distribution
pushd dist >/dev/null
zip -r "${PRODUCT_NAME}.zip" "${PRODUCT_NAME}.app"
popd >/dev/null

# Create a DMG image (compressed UDZO)
DMG_PATH="dist/${PRODUCT_NAME}.dmg"
DMG_ROOT="dist/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

echo "Creating DMG at $DMG_PATH ..."
hdiutil create -volname "$PRODUCT_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$DMG_ROOT"

# Sign DMG if signing is enabled
if [[ "$SIGN" -eq 1 ]]; then
  if [[ -z "$SIGN_IDENTITY" ]]; then
    # Try to detect again (Developer ID Application preferred)
    SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n1)
  fi
  if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing DMG..."
    /usr/bin/codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
    /usr/bin/codesign --verify --strict --verbose=2 "$DMG_PATH" || true
  fi
fi

# Notarize DMG if requested
if [[ "$NOTARIZE" -eq 1 ]]; then
  echo "Submitting DMG for notarization..."
  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$DMG_PATH" --wait --keychain-profile "$NOTARY_PROFILE"
  else
    if [[ -z "$APPLE_ID" || -z "$TEAM_ID" || -z "$APP_PASSWORD" ]]; then
      echo "error: For notarization provide either --notary-profile or --apple-id/--team-id/--password" >&2
      exit 1
    fi
    xcrun notarytool submit "$DMG_PATH" --wait \
      --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD"
  fi
  echo "Stapling tickets..."
  xcrun stapler staple "$APP_DIR"
  xcrun stapler staple "$DMG_PATH"
fi

echo "App packaged at dist/${PRODUCT_NAME}.app, dist/${PRODUCT_NAME}.zip, and dist/${PRODUCT_NAME}.dmg"
