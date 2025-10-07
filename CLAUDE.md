# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Development Setup
```bash
# Install dependencies
flutter pub get

# Run on specific platform
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter run -d android

# Hot reload in development: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
```

### Code Quality
```bash
# Analyze code
flutter analyze

# Format code
dart format lib test

# Run tests
flutter test

# Generate code (JSON serialization, icons)
flutter packages pub run build_runner build
```

### Build Commands
```bash
# Release builds
flutter build macos --release
flutter build windows --release
flutter build linux --release
flutter build apk --release

# Build with scripts
./build.sh                    # Generic build
./build_dmg.sh               # macOS DMG
./build_apk.sh               # Android APK
```

## Architecture Overview

This is a **Flutter desktop paraphrasing application** with two main modules:

### Core Paraphrasing Module
- **Entry Point**: `lib/main.dart` - Sets up window management and app theme
- **State Management**: Provider pattern with `ParaphraseProvider` in `lib/core/paraphrase_provider.dart`
- **Main Screen**: `lib/screens/main_screen.dart` - Primary UI for paraphrasing
- **API Integration**: OpenRouter API service in `lib/services/api_service.dart`
- **Key Services**:
  - `lib/services/clipboard_service.dart` - Clipboard management
  - `lib/services/system_integration_service.dart` - Global hotkeys and system tray
  - `lib/services/window_manager_service.dart` - Window behavior
  - `lib/services/settings_service.dart` - Settings persistence

### CSV Reader Module (Recent Addition)
- **Modern UI**: `lib/screens/csv_reader_screen_modern.dart` - Current production CSV viewer
- **Optimized UI**: `lib/screens/csv_reader_screen_optimized.dart` - Performance-focused version for large files
- **Streaming Service**: `lib/services/csv_streaming_service.dart` - Handles large CSV files (320k+ rows)
- **Database Service**: `lib/services/csv_database_service.dart` - SQLite storage for CSV data
- **History Service**: `lib/services/csv_history_service.dart` - Undo/redo functionality
- **Virtual Table**: `lib/widgets/virtual_csv_table.dart` - Virtualized rendering for performance
- **Key Features**:
  - Streaming CSV loading with progress indicators
  - Virtual scrolling for large datasets
  - Undo/redo system with mixins
  - Search and filter capabilities
  - History board for tracking changes

## Key Architecture Patterns

### State Management
- Uses Provider pattern with `ParaphraseProvider` for global state
- Individual screens manage local state with `StatefulWidget`
- Settings persisted with `shared_preferences` and secure storage for API keys

### Performance Optimizations
- **Virtual Scrolling**: `lib/widgets/virtual_csv_table.dart` for large CSV files
- **Streaming Processing**: `lib/services/csv_streaming_service.dart` loads files in chunks
- **Database Storage**: SQLite for CSV data instead of in-memory storage
- **Batch Operations**: Database inserts happen in batches of 5000 rows

### Mixins for Code Reuse
- `lib/mixins/csv_operations_mixin.dart` - Common CSV operations
- `lib/mixins/csv_undo_redo_mixin.dart` - Undo/redo functionality

### Platform Integration
- **Window Management**: Custom window styling and behavior
- **Global Hotkeys**: System-wide hotkey registration (Cmd+Shift+K)
- **System Tray**: Background operation capability
- **File Operations**: Cross-platform file picker and drag-and-drop

## File Structure Conventions

```
lib/
├── core/                     # Core business logic and providers
├── models/                   # Data models and domain objects
├── screens/                  # Full-screen UI components
├── widgets/                  # Reusable UI components
├── services/                 # External service integrations
├── mixins/                   # Reusable functionality mixins
└── theme/                    # App theming and styling
```

## Development Guidelines

### Code Style
- Follow Dart Style Guide with 2-space indentation
- Use `const` constructors where possible
- Prefer single quotes for strings
- Sort child properties last in widget constructors
- Use trailing commas for better formatting
- Line length under 100 characters when possible

### Testing
- Tests in `test/` directory mirroring `lib/` structure
- Use `flutter_test` framework
- Run `flutter test` before commits
- Use descriptive test names in present tense

### Build and Deployment
- Platform-specific builds require host OS (macOS builds only on macOS, etc.)
- Use provided build scripts for packaging (DMG, EXE, AppImage)
- Icons generated with `flutter_launcher_icons` configuration in `pubspec.yaml`

### Security
- API keys stored in platform secure storage (keychain, credential manager)
- No telemetry or data collection
- All API communication over HTTPS
- Never commit API keys or sensitive data

## CSV Module Specific Notes

### Performance Considerations
- Files with 320k+ rows require streaming approach
- Virtual table renders only visible rows
- Database storage prevents memory issues
- Batch operations maintain UI responsiveness

### Key Components
- **CsvStreamingService**: Handles progressive file loading
- **CsvDatabaseService**: Manages SQLite operations for CSV data
- **VirtualCsvTable**: Renders only visible portion of large datasets
- **CsvHistoryService**: Implements undo/redo with action tracking

### Development Workflow for CSV Features
1. Start with `csv_reader_screen_modern.dart` for UI development
2. Use `csv_reader_screen_optimized.dart` for performance testing
3. Test with large files (100k+ rows) to verify streaming works
4. Verify virtual scrolling maintains smooth performance
5. Test undo/redo functionality persists correctly