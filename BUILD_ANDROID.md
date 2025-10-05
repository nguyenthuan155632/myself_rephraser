# Building Android APK

Complete guide to building Myself Rephraser for Android.

---

## ⚠️ Important Note

**Myself Rephraser is designed as a desktop application**. Some features won't work on mobile:

- ❌ **Global Hotkeys** (Cmd+Shift+K) - Not supported on mobile
- ❌ **System Tray** - Mobile doesn't have system tray
- ❌ **Window Management** - Different on mobile
- ✅ **Core Paraphrasing** - Works perfectly
- ✅ **Settings** - Fully functional
- ✅ **UI** - Will work but may need mobile optimization

---

## 📋 Prerequisites

1. **Flutter SDK** installed
2. **Android Studio** (optional but recommended)
3. **Java JDK 11** or later
4. **Android SDK** (installed via Android Studio or command line)

---

## 🚀 Quick Build (Debug)

For testing purposes, no signing required:

```bash
# Build debug APK
flutter build apk --debug

# Output location:
# build/app/outputs/flutter-apk/app-debug.apk
```

Install on device:
```bash
# Via USB
flutter install

# Or manually
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🔐 Build Release APK (Signed)

### Step 1: Create Keystore

**Only do this once!** Keep your keystore safe - you'll need it for all future releases.

```bash
keytool -genkey -v \
  -keystore ~/myself-rephraser-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias myself-rephraser
```

You'll be prompted for:
- **Keystore password**: Choose a strong password (remember it!)
- **Key password**: Can be same as keystore password
- **Name**: Your name or company name
- **Organizational unit**: Your team/department (or just press Enter)
- **Organization**: Memorize Vault or your company
- **City**: Your city
- **State**: Your state/province
- **Country code**: Two-letter country code (e.g., US, VN)

**⚠️ IMPORTANT**: 
- Keep the `.jks` file safe - back it up!
- Remember your passwords
- If you lose either, you cannot update your app on Play Store

### Step 2: Configure Signing

Create `android/key.properties` file:

```bash
cd android
cp key.properties.template key.properties
```

Edit `key.properties` with your values:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD_HERE
keyPassword=YOUR_KEY_PASSWORD_HERE
keyAlias=myself-rephraser
storeFile=/Users/thuan.nv/myself-rephraser-release.jks
```

**Note**: This file is gitignored, so your passwords won't be committed.

### Step 3: Build Signed APK

```bash
# Build release APK
flutter build apk --release

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 📦 Build Split APKs (Recommended)

Split APKs create separate files for different CPU architectures, resulting in smaller downloads:

```bash
flutter build apk --split-per-abi --release
```

This creates 3 APKs:
- **app-armeabi-v7a-release.apk** (~40MB) - 32-bit ARM devices
- **app-arm64-v8a-release.apk** (~42MB) - 64-bit ARM devices (most modern phones)
- **app-x86_64-release.apk** (~45MB) - Intel/AMD devices (rare on phones)

**Tip**: Upload the arm64-v8a version for most users.

---

## 📱 Build App Bundle (for Google Play Store)

Google Play requires App Bundles (.aab) instead of APKs:

```bash
flutter build appbundle --release

# Output location:
# build/app/outputs/bundle/release/app-release.aab
```

**Benefits**:
- Google Play optimizes APK per device
- Smaller download size for users
- Required for Play Store submission

---

## 🧪 Testing

### Test on Emulator

```bash
# List available emulators
flutter emulators

# Start emulator
flutter emulators --launch <emulator_id>

# Run app
flutter run
```

### Test on Physical Device

1. **Enable Developer Options** on your Android device:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times

2. **Enable USB Debugging**:
   - Settings → Developer Options → USB Debugging

3. **Connect device** via USB

4. **Run app**:
```bash
flutter devices  # Verify device is detected
flutter run      # Run in debug mode
flutter install  # Install release APK
```

---

## 📊 APK Information

Check APK details:

```bash
# APK size
ls -lh build/app/outputs/flutter-apk/*.apk

# APK info (requires Android SDK)
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔍 Verify Signature

Verify your APK is properly signed:

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/flutter-apk/app-release.apk
```

Should output: `jar verified.`

---

## 📤 Distribution Options

### Option 1: Google Play Store

1. **Create Developer Account**: https://play.google.com/console
2. **Upload AAB**: Use `app-release.aab`
3. **Fill app details**: Description, screenshots, etc.
4. **Submit for review**

### Option 2: Direct Distribution

Share APK file directly:
- Email
- Cloud storage (Google Drive, Dropbox)
- Your website
- GitHub Releases

**Note**: Users must enable "Install from Unknown Sources" in Settings.

### Option 3: Third-Party Stores

- Amazon Appstore
- Samsung Galaxy Store
- APKPure
- F-Droid (requires open source)

---

## 🐛 Troubleshooting

### Error: "Execution failed for task ':app:signReleaseBundle'"

**Solution**: Check your `key.properties` file:
- Passwords are correct
- Keystore file path is correct (absolute path)
- File exists at specified location

### Error: "SDK location not found"

**Solution**: Set Android SDK path:
```bash
# Create/edit android/local.properties
echo "sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk" > android/local.properties
```

### Error: "Gradle build failed"

**Solution**: Clean and rebuild:
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter build apk --release
```

### Error: "Minimum SDK version"

Some plugins may require higher minSdk. Edit `android/app/build.gradle.kts`:
```kotlin
minSdk = 21  // or higher if needed
```

---

## ⚙️ Advanced Configuration

### Change App Name

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="Myself Rephraser"
    ...>
```

### Change App Icon

Replace icons in:
- `android/app/src/main/res/mipmap-hdpi/`
- `android/app/src/main/res/mipmap-mdpi/`
- `android/app/src/main/res/mipmap-xhdpi/`
- `android/app/src/main/res/mipmap-xxhdpi/`
- `android/app/src/main/res/mipmap-xxxhdpi/`

Or use Flutter launcher icons:
```bash
flutter pub add flutter_launcher_icons
```

### Permissions

Add permissions in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## 📝 Build Checklist

Before releasing:

- [ ] Update version in `pubspec.yaml`
- [ ] Test on multiple devices/Android versions
- [ ] Check APK size (should be under 50MB per architecture)
- [ ] Verify app signing
- [ ] Test all features work
- [ ] Check app icon appears correctly
- [ ] Review permissions requested
- [ ] Test on slow internet connection
- [ ] Verify API key input works
- [ ] Test paraphrasing functionality
- [ ] Check dark mode works

---

## 📊 Version Information

- **Current Version**: 1.0.0
- **Min Android Version**: API 21 (Android 5.0 Lollipop)
- **Target Android Version**: API 34 (Android 14)
- **Package Name**: `com.memorizevault.myselfrephraser`

---

## 🔗 Useful Links

- [Flutter Android Build Docs](https://docs.flutter.dev/deployment/android)
- [Android Studio](https://developer.android.com/studio)
- [Google Play Console](https://play.google.com/console)
- [Android Signing Guide](https://developer.android.com/studio/publish/app-signing)

---

## 📧 Support

For build issues, contact: nt.apple.it@gmail.com

---

**Copyright © 2025 Memorize Vault (Vensera)**

