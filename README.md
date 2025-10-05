# Myself Rephraser

AI-powered desktop paraphrasing application built with Flutter.

## Features

- **Multiple Paraphrasing Modes**: Formal, Simple, Shorten, Creative
- **System Integration**: Global hotkey support, system tray integration
- **AI Powered**: Uses OpenRouter API with multiple model options
- **Cross Platform**: Supports macOS and Windows
- **Secure Storage**: API keys stored securely
- **Customizable**: Dark/light theme, font size adjustment

## Setup

### Prerequisites

- Flutter 3.9.2 or higher
- OpenRouter API key (get one at [openrouter.ai](https://openrouter.ai))

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd myself_rephraser
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure your API key in the app settings

### Building

#### macOS
```bash
flutter build macos --release
```

#### Windows
```bash
flutter build windows --release
```

## Usage

1. **Set up API Key**: Open the app and configure your OpenRouter API key in settings
2. **Use Global Hotkey**: Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows) to open the paraphraser overlay
3. **Select Mode**: Choose from Formal, Simple, Shorten, or Creative modes
4. **Paraphrase**: Enter your text and click "Paraphrase"
5. **Copy Result**: Copy the paraphrased text to clipboard

## Settings

- **API Configuration**: Set your OpenRouter API key and choose AI model
- **Shortcuts**: Configure global hotkey
- **Appearance**: Toggle dark mode, adjust font size
- **Advanced**: Start at login, clear cache

## Supported AI Models

- GPT-3.5 Turbo
- GPT-4
- Claude 3 Haiku
- Claude 3 Sonnet

## Development

### Project Structure

```
lib/
├── core/                  # Core business logic
├── models/                # Data models
├── services/              # API and system services
├── widgets/               # Reusable UI components
└── screens/               # Main app screens
```

### Running in Development

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows
```

## Security

- API keys are stored using secure storage (Keychain on macOS, Credential Vault on Windows)
- All API calls are encrypted over HTTPS
- No user data is stored on external servers

## Troubleshooting

### Common Issues

1. **Hotkey not working**: Check system permissions for accessibility/automation
2. **API errors**: Verify your OpenRouter API key is valid and has credits
3. **Build issues**: Make sure you have the latest Flutter SDK

### Permissions

#### macOS
- Accessibility permissions for global hotkeys
- Full disk access for clipboard integration

#### Windows
- UI Automation permissions for global hotkeys

## License

[License information]

## Contributing

[Contributing guidelines]