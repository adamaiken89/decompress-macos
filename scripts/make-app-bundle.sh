#!/bin/bash
# Package SPM-built binary(ies) into a universal macOS .app bundle.
# Usage: ./scripts/make-app-bundle.sh <binary1> [binary2 ...]
# If multiple binaries are given, lipo merges them into a universal binary.
# The built .app is placed in the current directory.

set -euo pipefail

PRODUCT_NAME="Decompress"
APP_NAME="${PRODUCT_NAME}.app"
APP_DIR="$APP_NAME/Contents"
APP_BINARY="$APP_DIR/MacOS/$PRODUCT_NAME"
APP_PLIST="$APP_DIR/Info.plist"
APP_ICON="$APP_DIR/Resources/$PRODUCT_NAME.icns"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Creating .app bundle ==="

mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path-to-binary>"
    exit 1
fi
cp "$1" "$APP_BINARY"
chmod +x "$APP_BINARY"

# Info.plist
if [ -f "$REPO_DIR/support/Info.plist" ]; then
    cp "$REPO_DIR/support/Info.plist" "$APP_PLIST"
else
    cat > "$APP_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.decompress-macos.app</string>
    <key>CFBundleName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
fi

# App icon
echo "  Generating app icon..."
iconset="${PRODUCT_NAME}.iconset"
mkdir -p "$iconset"

swift - <<'SWIFT' 2>/dev/null || true
import Cocoa
import Foundation
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let rect = NSRect(origin: .zero, size: size)
NSColor.systemBlue.setFill()
rect.fill()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 500, weight: .bold),
    .foregroundColor: NSColor.white,
]
let str = NSAttributedString(string: "D", attributes: attrs)
let strSize = str.size()
str.draw(at: NSPoint(x: (size.width - strSize.width) / 2, y: (size.height - strSize.height) / 2 - 30))
image.unlockFocus()
guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let rep = NSBitmapImageRep(cgImage: cgImage),
      let data = rep.representation(using: .png, properties: [:])
else { fatalError() }
try data.write(to: URL(fileURLWithPath: "icon_1024.png"))
SWIFT

if [ -f icon_1024.png ]; then
    sips -z 16 16 icon_1024.png --out "$iconset/icon_16x16.png" &>/dev/null
    sips -z 32 32 icon_1024.png --out "$iconset/icon_16x16@2x.png" &>/dev/null
    sips -z 32 32 icon_1024.png --out "$iconset/icon_32x32.png" &>/dev/null
    sips -z 64 64 icon_1024.png --out "$iconset/icon_32x32@2x.png" &>/dev/null
    sips -z 128 128 icon_1024.png --out "$iconset/icon_128x128.png" &>/dev/null
    sips -z 256 256 icon_1024.png --out "$iconset/icon_128x128@2x.png" &>/dev/null
    sips -z 256 256 icon_1024.png --out "$iconset/icon_256x256.png" &>/dev/null
    sips -z 512 512 icon_1024.png --out "$iconset/icon_256x256@2x.png" &>/dev/null
    sips -z 512 512 icon_1024.png --out "$iconset/icon_512x512.png" &>/dev/null
    cp icon_1024.png "$iconset/icon_512x512@2x.png"
    iconutil -c icns "$iconset" -o "$APP_ICON" 2>/dev/null || echo "  Warning: icon generation failed"
    rm -rf "$iconset" icon_1024.png
fi

# Code-sign
if command -v codesign &>/dev/null; then
    echo "  Signing app bundle..."
    codesign --force --deep --sign - "$APP_NAME" 2>/dev/null || true
fi

echo "=== Bundle created: $APP_NAME ==="
