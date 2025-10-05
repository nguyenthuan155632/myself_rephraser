#!/bin/bash

# Build script for Myself Rephraser Desktop App

echo "Building Myself Rephraser..."

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Run tests
echo "Running tests..."
flutter test

# Analyze code
echo "Analyzing code..."
flutter analyze

# Build for current platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building for macOS..."
    flutter build macos --release
    echo "✅ macOS build complete: build/macos/Build/Products/Release/myself_rephraser.app"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "Building for Windows..."
    flutter build windows --release
    echo "✅ Windows build complete: build/windows/runner/Release/"
else
    echo "Unknown OS. Building for current platform..."
    flutter build --release
fi

echo "Build process completed!"