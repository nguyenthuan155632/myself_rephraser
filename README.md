# Myself Rephraser

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)
![License](https://img.shields.io/badge/license-Proprietary-red)

**AI-powered text paraphrasing desktop application built with Flutter**

Transform your text with intelligent AI rephrasing at the press of a hotkey. Get multiple paraphrasing options instantly with support for various writing styles.

---

## 📖 Documentation

- **[User Guide](USER_GUIDE.md)** - Complete usage documentation for end users
- **[Build Instructions](#-building-from-source)** - How to build for different platforms
- **[API Documentation](#-api-integration)** - OpenRouter API integration details

---

## ✨ Features

- 🚀 **Global Hotkey Access** - Quick access from any application (Cmd+Shift+K)
- 🤖 **Multiple AI Models** - Support for Gemini, Claude, GPT-4, Llama, and more
- 🎨 **6 Paraphrase Modes** - Formal, Casual, Creative, Concise, Academic, Technical
- 📝 **3 Variations** - Get 3 different options for each paraphrase
- 💾 **Smart Clipboard** - Auto-paste from clipboard
- 🎯 **System Tray** - Runs quietly in the background
- 🌓 **Dark Mode** - Full theme support
- 💻 **Cross-Platform** - macOS, Windows, Linux

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.0+
- **Language**: Dart 3.0+
- **API Provider**: OpenRouter
- **State Management**: Provider
- **Key Dependencies**:
  - `hotkey_manager` - Global hotkey support
  - `window_manager` - Window management
  - `system_tray` - System tray integration
  - `flutter_secure_storage` - Secure API key storage
  - `shared_preferences` - Settings persistence
  - `http` - API communication

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0 or later
- Dart SDK 3.0 or later
- OpenRouter API key (get one at [openrouter.ai](https://openrouter.ai))

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/myself_rephaser.git
cd myself_rephaser
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Run the app**
```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

---

## 📦 Building from Source

### Platform Requirements

| Build Target | Required Host OS | Notes |
|--------------|------------------|-------|
| macOS DMG | macOS | Cannot build on Windows/Linux |
| Windows EXE | Windows | Cannot build on macOS/Linux |
| Linux | Linux | Can use Docker on macOS |

**Current Platform**: You're on macOS, so you can only build macOS apps directly.

### Build for macOS

```bash
# Build release
flutter build macos --release

# Output location:
# build/macos/Build/Products/Release/myself_rephaser.app

# Create DMG (requires create-dmg)
brew install create-dmg

create-dmg \
  --volname "Myself Rephraser" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "myself_rephaser.app" 200 190 \
  --app-drop-link 600 185 \
  "MyselfRephraser.dmg" \
  "build/macos/Build/Products/Release/myself_rephaser.app"
```

### Build for Windows

**⚠️ Note**: Windows builds require a Windows host machine. Cannot be built on macOS or Linux.

```bash
# Build release (on Windows PC)
flutter build windows --release

# Output location:
# build/windows/x64/runner/Release/

# Create installer using Inno Setup
# 1. Install Inno Setup from https://jrsoftware.org/isdl.php
# 2. Create installer.iss (see below)
# 3. Run: iscc installer.iss
```

**Inno Setup Script (installer.iss)**:
```iss
[Setup]
AppName=Myself Rephraser
AppVersion=1.0.0
DefaultDirName={autopf}\MyselfRephraser
DefaultGroupName=Myself Rephraser
OutputDir=installers
OutputBaseFilename=MyselfRephraser-Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Myself Rephraser"; Filename: "{app}\myself_rephaser.exe"
Name: "{autodesktop}\Myself Rephraser"; Filename: "{app}\myself_rephaser.exe"

[Run]
Filename: "{app}\myself_rephaser.exe"; Description: "Launch Myself Rephraser"; Flags: postinstall nowait skipifsilent
```

### Build for Linux

**⚠️ Note**: Linux builds require a Linux host machine (or Docker on macOS).

```bash
# Build release (on Linux PC)
flutter build linux --release

# Output location:
# build/linux/x64/release/bundle/

# Create AppImage (requires appimagetool)
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage

# Package as AppImage
./appimagetool-x86_64.AppImage build/linux/x64/release/bundle/ MyselfRephraser.AppImage
```

---

## 🏗️ Project Structure

```
myself_rephaser/
├── lib/
│   ├── core/                    # Core business logic
│   │   └── paraphrase_provider.dart
│   ├── models/                  # Data models
│   │   ├── paraphrase.dart
│   │   └── settings.dart
│   ├── screens/                 # Main screens
│   │   └── main_screen.dart
│   ├── widgets/                 # Reusable widgets
│   │   ├── paraphrase_overlay.dart
│   │   ├── paraphrase_result_card.dart
│   │   └── settings_screen.dart
│   ├── services/                # External services
│   │   ├── api_service.dart
│   │   ├── clipboard_service.dart
│   │   ├── mouse_position_service.dart
│   │   ├── settings_service.dart
│   │   ├── system_integration_service.dart
│   │   └── window_manager_service.dart
│   └── main.dart
├── macos/                       # macOS specific code
├── windows/                     # Windows specific code
├── linux/                       # Linux specific code
├── assets/                      # Images, icons, etc.
├── pubspec.yaml                 # Dependencies
├── README.md                    # This file
└── USER_GUIDE.md               # End-user documentation
```

---

## 🔧 Configuration

### API Configuration

The app uses OpenRouter API for AI paraphrasing. Users need to configure their API key in the app settings.

**Supported Models**:
- Google Gemini 2.5 Flash Lite (default)
- Anthropic Claude 3.5 Sonnet
- OpenAI GPT-4o
- Meta Llama 3.3 70B
- OpenAI GPT-3.5 Turbo

### Environment Variables

No environment variables required. All configuration is done through the app UI.

### Settings Storage

- **API Key**: Stored in system keychain (macOS), Credential Manager (Windows), Secret Service (Linux)
- **Other Settings**: Stored in `shared_preferences` (platform-specific locations)

---

## 🔌 API Integration

### OpenRouter API

The app uses OpenRouter as a unified gateway to multiple AI models.

**Endpoint**: `https://openrouter.ai/api/v1/chat/completions`

**Request Format**:
```json
{
  "model": "google/gemini-2.5-flash-lite-preview-09-2025",
  "messages": [
    {
      "role": "user",
      "content": "Please provide exactly 3 different formal rephrases..."
    }
  ]
}
```

**Response Parsing**:
The app parses responses to extract 3 numbered variations using regex patterns.

### Rate Limiting

OpenRouter implements their own rate limiting. The app does not implement additional rate limiting.

---

## 🧪 Development

### Running in Debug Mode

```bash
flutter run -d macos --debug
```

### Hot Reload

Flutter's hot reload is supported. Press `r` in the terminal to reload.

### Linting

```bash
flutter analyze
```

### Testing

```bash
flutter test
```

---

## 📝 Code Style

This project follows the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).

**Key Points**:
- Use `const` constructors where possible
- Prefer single quotes for strings
- Sort child properties last in widget constructors
- Use trailing commas for better formatting

**Linting**: Configured in `analysis_options.yaml`

---

## 🐛 Known Issues

1. **macOS Hotkey After Hot Restart**: Hotkey may not work after hot restart in development. Fixed by proper cleanup in `system_integration_service.dart`.

2. **Windows Elevation**: Some Windows installations may require running as administrator for global hotkeys to work.

3. **Linux Wayland**: System tray may not work on Wayland. Use X11 for full functionality.

---

## 🗺️ Roadmap

### Planned Features

- [ ] History of paraphrases
- [ ] Custom paraphrase modes
- [ ] Batch processing
- [ ] Export to file
- [ ] Keyboard navigation
- [ ] Multi-language support
- [ ] Offline mode (cached results)
- [ ] Browser extension integration
- [ ] Custom API endpoint support

### Future Improvements

- [ ] Performance optimizations
- [ ] Reduced memory footprint
- [ ] Faster startup time
- [ ] Better error handling
- [ ] Comprehensive testing suite
- [ ] CI/CD pipeline

---

## 🤝 Contributing

This is a proprietary project. Contributions are not currently accepted.

---

## 📄 License

Copyright © 2025 Memorize Vault (Vensera). All rights reserved.

This software is proprietary and confidential. Unauthorized copying, modification, distribution, or use of this software, via any medium, is strictly prohibited.

---

## 👤 Contact

**Memorize Vault (Vensera)**

- **Email**: nt.apple.it@gmail.com
- **Support**: For bug reports and feature requests, contact via email

---

## 🙏 Acknowledgments

- **OpenRouter** - For providing unified AI API access
- **Flutter Team** - For the amazing cross-platform framework
- **AI Providers** - Google (Gemini), Anthropic (Claude), OpenAI (GPT), Meta (Llama)
- **Open Source Community** - For the excellent Flutter packages

---

## 📊 Statistics

- **Lines of Code**: ~3,000+
- **Number of Files**: 20+
- **Supported Platforms**: 3 (macOS, Windows, Linux)
- **AI Models**: 5+
- **Paraphrase Modes**: 6

---

## 🔒 Security

### Security Best Practices

1. **API Key Storage**: Uses platform-specific secure storage
2. **No Telemetry**: App does not collect or send usage data
3. **Local Processing**: All settings stored locally
4. **HTTPS Only**: All API communication over HTTPS

### Reporting Security Issues

If you discover a security vulnerability, please email: nt.apple.it@gmail.com

Do not create public issues for security vulnerabilities.

---

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter Desktop](https://docs.flutter.dev/desktop)

---

## 💻 System Requirements

### Development

- **macOS**: Xcode 14.0+ (for macOS builds)
- **Windows**: Visual Studio 2022+ (for Windows builds)
- **Linux**: Clang, CMake, Ninja (for Linux builds)
- **All Platforms**: Flutter SDK 3.0+, Dart SDK 3.0+

### Runtime

- **macOS**: 10.14 (Mojave) or later
- **Windows**: Windows 10 or later
- **Linux**: Ubuntu 18.04 or equivalent
- **RAM**: 4 GB minimum, 8 GB recommended
- **Storage**: 200 MB free space

---

## 🎯 Version Information

- **Current Version**: 1.0.0
- **Release Date**: January 2025
- **Minimum Flutter Version**: 3.0.0
- **Minimum Dart Version**: 3.0.0

---

**Built with ❤️ using Flutter**

*Last Updated: January 2025*
