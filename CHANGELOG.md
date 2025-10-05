# Changelog

All notable changes to Myself Rephraser will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025-01-XX

### 🎉 Initial Release

First public release of Myself Rephraser - AI-powered desktop text paraphrasing application.

### ✨ Features

#### Core Functionality
- **Global Hotkey Access**: Quick access from any application (Cmd+Shift+K / Ctrl+Shift+K)
- **AI-Powered Paraphrasing**: Uses OpenRouter API for intelligent text rephrasing
- **Multiple AI Models**: Support for Gemini, Claude, GPT-4, Llama, and more
- **6 Paraphrase Modes**:
  - Formal: Professional, business-appropriate language
  - Casual: Friendly, conversational tone
  - Creative: Expressive, vivid language
  - Concise: Brief, to-the-point rephrasing
  - Academic: Scholarly, research-oriented style
  - Technical: Clear, precise technical writing
- **3 Variations Per Request**: Get multiple options for each paraphrase
- **One-Click Copy**: Instantly copy any variation to clipboard

#### User Interface
- **Modern, Professional Design**: Clean interface with Material Design 3
- **Dark Mode Support**: Full theme support with light and dark modes
- **Floating Overlay**: Non-intrusive overlay that appears at cursor position
- **System Tray Integration**: Minimizes to system tray for quick access
- **Smart Result Cards**: 
  - Each option displayed in its own card
  - Word and character count for each variation
  - AI model badge showing which model was used
  - Individual copy buttons for each option

#### System Integration
- **Cross-Platform**: macOS, Windows, and Linux support
- **Window Management**: Intelligent window positioning and focus management
- **Clipboard Integration**: Auto-paste from clipboard into overlay
- **Background Operation**: Runs quietly in system tray
- **Mode Memory**: Remembers last selected paraphrase mode

#### Settings & Configuration
- **API Key Management**: Secure storage using system keychain
- **Model Selection**: Choose from multiple AI models
- **Hotkey Customization**: Configurable global hotkey
- **Theme Selection**: Toggle between light and dark modes

### 🎨 Design Highlights

#### Visual Improvements
- **Gradient Backgrounds**: Subtle gradients throughout the UI
- **Elevated Shadows**: Multi-layered shadows for depth
- **Rounded Corners**: Modern 16-24px border radius
- **Consistent Spacing**: 8px grid system
- **Professional Typography**: Proper hierarchy and spacing
- **Icon Integration**: Contextual icons throughout

#### Component Design
- **Paraphrase Overlay** (1200x900px):
  - Gradient header with icon and subtitle
  - Larger text input (8 lines)
  - Enhanced dropdown with mode selection
  - Prominent CTA button with shadow glow
  
- **Result Cards**:
  - Clean white surface with elevated shadows
  - Gradient headers with AI model badges
  - Colored option labels
  - Improved copy buttons
  - Statistics with icons (word/char count)

- **Main Screen**:
  - Background gradient
  - Hero icon with circular gradient container
  - Status cards with different states (error/ready)
  - Modern button designs
  - Professional layout

- **Settings Screen**:
  - Section cards with icon headers
  - Better spacing and organization
  - Enhanced form fields
  - Prominent save button

### 🔧 Technical Details

#### Architecture
- **Framework**: Flutter 3.0+
- **Language**: Dart 3.0+
- **State Management**: Provider
- **API Integration**: OpenRouter (unified AI gateway)

#### Dependencies
- `hotkey_manager`: ^0.2.3 - Global hotkey support
- `window_manager`: ^0.5.1 - Window management
- `system_tray`: ^2.0.3 - System tray integration
- `flutter_secure_storage`: ^9.2.2 - Secure API key storage
- `shared_preferences`: ^2.3.2 - Settings persistence
- `http`: ^1.2.2 - API communication
- `provider`: ^6.1.2 - State management

#### Platform Support
- **macOS**: 10.14 (Mojave) or later
- **Windows**: Windows 10 or later
- **Linux**: Ubuntu 18.04 or equivalent

### 🐛 Bug Fixes

#### Resolved Issues
- Fixed dropdown overflow in paraphrase mode selection
- Fixed hotkey not working after hot restart
- Fixed overlay size not matching 1200x900 dimensions
- Fixed toggle functionality for overlay (open/close behavior)
- Removed unused code and imports
- Fixed linting issues (disabled `avoid_print` for desktop debugging)

#### UI Fixes
- Removed numbering (1., 2., 3.) from displayed paraphrased options
- Fixed RenderFlex overflow errors
- Corrected container constraints and sizing
- Improved text wrapping and layout

### 📝 Configuration Changes

#### Branding & Identity
- **App Name**: Changed from "myself_rephraser" to "Myself Rephraser"
- **Bundle ID**: Updated to `com.memorizevault.myselfrephraser`
- **Copyright**: "© 2025 Memorize Vault (Vensera)"
- **Contact**: nt.apple.it@gmail.com

#### Removed Features
- Font Size setting (not implemented)
- Start at Login setting (not implemented)

### 📚 Documentation

#### Added Documentation
- **USER_GUIDE.md**: Comprehensive user documentation (498 lines)
  - Installation instructions
  - Feature documentation
  - Paraphrase mode guide
  - Settings reference
  - Troubleshooting guide
  - Privacy & security information

- **README.md**: Technical documentation (431 lines)
  - Build instructions for all platforms
  - Project structure
  - API integration details
  - Development guide
  - Contributing guidelines

- **CHANGELOG.md**: This file

#### Build Scripts
- **build_dmg.sh**: Automated macOS DMG creation script
- Inno Setup script template for Windows installer
- AppImage packaging instructions for Linux

### 🔐 Security & Privacy

- Secure API key storage using system keychain
- No telemetry or analytics collection
- Local settings storage only
- HTTPS-only API communication
- No data retention on servers

### 🎯 Known Limitations

- Requires internet connection for API access
- Paraphrasing costs depend on selected AI model
- Windows may require administrator privileges for global hotkeys
- Linux Wayland may have limited system tray support

---

## Future Releases

### Planned for 1.1.0
- [ ] History of paraphrases
- [ ] Custom paraphrase modes
- [ ] Batch processing
- [ ] Export to file
- [ ] Keyboard navigation improvements

### Under Consideration
- [ ] Multi-language support
- [ ] Offline mode with cached results
- [ ] Browser extension integration
- [ ] Custom API endpoint support
- [ ] Plugins/extensions system

---

## Version History

- **1.0.0** (2025-01-XX) - Initial release

---

**Note**: Dates marked with "XX" will be updated upon official release.

For support or bug reports, contact: nt.apple.it@gmail.com

Copyright © 2025 Memorize Vault (Vensera). All rights reserved.

