#!/bin/bash

echo "🚀 Building Myself Rephraser for macOS..."

# Build the app
flutter build macos --release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo "📦 Creating DMG..."

# App path and DMG name
APP_PATH="build/macos/Build/Products/Release/Myself Rephraser.app"
DMG_NAME="MyselfRephraser.dmg"
TEMP_DIR="dmg_temp"

# Clean up any existing DMG and temp directory
rm -f "$DMG_NAME"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copy app to temp directory
echo "📋 Copying app bundle..."
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create Applications symlink
echo "🔗 Creating Applications link..."
ln -s /Applications "$TEMP_DIR/Applications"

# Create DMG
echo "💿 Creating disk image..."
hdiutil create -volname "Myself Rephraser" \
  -srcfolder "$TEMP_DIR" \
  -ov -format UDZO \
  "$DMG_NAME"

# Clean up
rm -rf "$TEMP_DIR"

if [ -f "$DMG_NAME" ]; then
    echo ""
    echo "✅ DMG created successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Location: $(pwd)/$DMG_NAME"
    echo "📊 Size: $(du -h "$DMG_NAME" | cut -f1)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 Ready for distribution!"
else
    echo "❌ DMG creation failed!"
    exit 1
fi

