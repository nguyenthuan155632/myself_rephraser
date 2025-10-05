# CRUSH.md

## Development Commands

### Setup
```bash
flutter pub get
```

### Development
```bash
# Run on macOS
flutter run -d macos

# Run on Windows  
flutter run -d windows
```

### Build
```bash
# Debug builds
flutter build macos --debug
flutter build windows --debug

# Release builds
flutter build macos --release
flutter build windows --release
```

### Analysis
```bash
flutter analyze
```

### Testing
```bash
flutter test
```

## Project Structure

- `lib/core/` - Business logic and state management
- `lib/models/` - Data models (ParaphraseMode, AppSettings, etc.)
- `lib/services/` - External services (API, storage, system integration)
- `lib/widgets/` - Reusable UI components
- `lib/screens/` - Main application screens

## Key Features Implemented

1. **Paraphrasing Modes**: Formal, Simple, Shorten, Creative
2. **OpenRouter API Integration**: Support for GPT-3.5, GPT-4, Claude models
3. **System Integration**: Global hotkeys, system tray, window management
4. **Secure Storage**: API keys stored in platform secure storage
5. **Responsive UI**: Material Design 3, dark/light theme support
6. **Settings Management**: Comprehensive settings with validation

## API Configuration

- Uses OpenRouter API for text paraphrasing
- Supports multiple AI models
- API key required (stored securely)
- Error handling and rate limit support

## Permissions Required

### macOS
- Accessibility permissions (for global hotkeys)
- Full disk access (for clipboard integration)

### Windows
- UI Automation permissions (for global hotkeys)

## Notes

- System tray integration needs icon assets in `assets/` folder
- Global hotkey default: `Cmd+Shift+K` (macOS) / `Ctrl+Shift+L` (Windows)
- App minimizes to system tray instead of closing
- All text processing happens via OpenRouter API (no local AI models)