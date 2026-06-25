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

# Copy SPM resource bundle (Decompress_Decompress.bundle) so Bundle.module resolves.
RESOURCE_BUNDLE="$(dirname "$1")/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Resources/"
else
    echo "  Warning: resource bundle not found at $RESOURCE_BUNDLE (localized strings may crash at launch)"
fi

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
    <string>0.0.0</string>
    <key>CFBundleVersion</key>
    <string>0</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
fi

# Override version from environment variables (used by CI)
if [ -n "${APP_VERSION:-}" ]; then
    plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_PLIST" 2>/dev/null || true
fi
if [ -n "${APP_BUILD_NUMBER:-}" ]; then
    plutil -replace CFBundleVersion -string "$APP_BUILD_NUMBER" "$APP_PLIST" 2>/dev/null || true
fi

# App icon
echo "  Generating app icon..."
iconset="${PRODUCT_NAME}.iconset"
mkdir -p "$iconset"

swift - <<'SWIFT' 2>/dev/null || true
import Cocoa

let W: CGFloat = 1024
let H: CGFloat = 1024

guard let ctx = CGContext(
  data: nil,
  width: Int(W), height: Int(H),
  bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpaceCreateDeviceRGB(),
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext") }

// -- Shadow --
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))

// -- Rounded-rect background --
let box = CGRect(x: 60, y: 180, width: W - 120, height: H - 240)
let corner: CGFloat = 80
ctx.beginPath()
ctx.addPath(CGPath(roundedRect: box, cornerWidth: corner, cornerHeight: corner, transform: nil))
ctx.closePath()

// Gradient fill
let topColor = CGColor(red: 0.22, green: 0.50, blue: 0.92, alpha: 1)
let botColor = CGColor(red: 0.12, green: 0.32, blue: 0.72, alpha: 1)
let grad = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: [topColor, botColor] as CFArray,
  locations: [0, 1]
)!
ctx.clip()
ctx.drawLinearGradient(grad, start: CGPoint(x: W / 2, y: box.maxY), end: CGPoint(x: W / 2, y: box.minY), options: [])
ctx.restoreGState()

// -- Zip band (horizontal strip across middle) --
let bandY: CGFloat = H / 2 - 40
let bandH: CGFloat = 80
let bandRect = CGRect(x: box.minX + 30, y: bandY, width: box.width - 60, height: bandH)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 6, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
ctx.beginPath()
ctx.addPath(CGPath(roundedRect: bandRect, cornerWidth: 20, cornerHeight: 20, transform: nil))
ctx.closePath()
ctx.setFillColor(CGColor(red: 0.10, green: 0.25, blue: 0.55, alpha: 0.92))
ctx.fillPath()
ctx.restoreGState()

// Zip teeth (small rectangles along the band)
let teethCount = 18
let teethW: CGFloat = 22
let teethH: CGFloat = 30
let gap = (bandRect.width - CGFloat(teethCount) * teethW) / CGFloat(teethCount + 1)
for i in 0..<teethCount {
  let tx = bandRect.minX + gap + CGFloat(i) * (teethW + gap)
  let ty = bandRect.midY - teethH / 2
  let tr = CGRect(x: tx, y: ty, width: teethW, height: teethH)
  ctx.beginPath()
  ctx.addPath(CGPath(roundedRect: tr, cornerWidth: 4, cornerHeight: 4, transform: nil))
  ctx.closePath()
  ctx.setFillColor(CGColor(red: 0.20, green: 0.42, blue: 0.78, alpha: 1))
  ctx.fillPath()
}

// -- Upward arrow (extraction) --
let arrowCx = W / 2
let arrowTipY: CGFloat = box.maxY - 100
let arrowBaseY: CGFloat = bandRect.maxY + 30
let arrowW: CGFloat = 180

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.3))

// Arrow triangle (pointing up)
ctx.beginPath()
ctx.move(to: CGPoint(x: arrowCx, y: arrowTipY))
ctx.addLine(to: CGPoint(x: arrowCx - arrowW / 2, y: arrowBaseY))
ctx.addLine(to: CGPoint(x: arrowCx + arrowW / 2, y: arrowBaseY))
ctx.closePath()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
ctx.fillPath()

// Arrow stem
let stemW: CGFloat = 60
let stemTop = arrowBaseY
let stemBot = bandRect.maxY + 8
let stemRect = CGRect(x: arrowCx - stemW / 2, y: stemBot, width: stemW, height: stemTop - stemBot)
ctx.beginPath()
ctx.addPath(CGPath(roundedRect: stemRect, cornerWidth: 10, cornerHeight: 10, transform: nil))
ctx.closePath()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
ctx.fillPath()

ctx.restoreGState()

// -- Export PNG --
guard let image = ctx.makeImage() else { fatalError("makeImage") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG") }
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
