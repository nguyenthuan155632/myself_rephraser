#!/bin/bash

echo "🤖 Building Myself Rephraser for Android..."
echo ""

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
    echo "⚠️  Warning: android/key.properties not found"
    echo "Building with debug signing..."
    echo ""
    SIGN_TYPE="debug"
else
    echo "✅ Found signing configuration"
    SIGN_TYPE="release"
fi

# Clean build
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to get dependencies!"
    exit 1
fi

# Build APK
if [ "$SIGN_TYPE" == "release" ]; then
    echo ""
    echo "📦 Building signed release APK..."
    echo ""
    
    # Build split APKs for smaller size
    flutter build apk --split-per-abi --release
    
    if [ $? -ne 0 ]; then
        echo "❌ Build failed!"
        exit 1
    fi
    
    echo ""
    echo "✅ Build successful!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Location: build/app/outputs/flutter-apk/"
    echo ""
    echo "Generated APKs:"
    ls -lh build/app/outputs/flutter-apk/*.apk | awk '{print "   " $9 " (" $5 ")"}'
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📱 Recommended: Upload app-arm64-v8a-release.apk (most modern devices)"
    
else
    echo ""
    echo "📦 Building debug APK..."
    echo ""
    
    flutter build apk --debug
    
    if [ $? -ne 0 ]; then
        echo "❌ Build failed!"
        exit 1
    fi
    
    echo ""
    echo "✅ Build successful!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Location: build/app/outputs/flutter-apk/app-debug.apk"
    echo "📊 Size: $(du -h build/app/outputs/flutter-apk/app-debug.apk | cut -f1)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⚠️  This is a DEBUG build - not for distribution!"
    echo "💡 Create android/key.properties to build signed release APK"
fi

echo ""
echo "🎉 Ready for testing!"
echo ""
echo "To install on connected device:"
echo "  adb install build/app/outputs/flutter-apk/app-*.apk"
echo ""

