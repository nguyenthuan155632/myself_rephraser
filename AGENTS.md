# Repository Guidelines

## Project Structure & Module Organization
The Flutter entry point lives in `lib/main.dart`, with feature logic organized by concern: `lib/core` for configuration and utilities, `lib/models` for API and state objects, `lib/services` for OpenRouter integration, and `lib/screens` plus `lib/widgets` for UI. Theme assets sit in `lib/theme`. Platform scaffolding is generated under `macos/`, `windows/`, `linux/`, `android/`, `ios/`, and `web/`, while distributable scripts live in `build*.sh` and `tools/`. Store shared images in `assets/`, and keep automated checks and docs in `test/` and `docs/` respectively.

## Build, Test, and Development Commands
Run `flutter pub get` after cloning or when dependencies change. Use `flutter run -d macos` (or the appropriate device flag) for local smoke testing, and `flutter build macos --release` for shipping artifacts. Lint the codebase with `flutter analyze` and format touched files via `dart format lib test`. Regenerate platform bundles through the accompanying `build_*.sh` scripts when packaging installers.

## Coding Style & Naming Conventions
Follow Dart's default two-space indentation and keep lines under 100 characters when possible. The analyzer is configured through `analysis_options.yaml`; respect enforced lints such as `prefer_single_quotes`, `prefer_const_constructors`, `prefer_final_fields`, and `use_key_in_widget_constructors`. Prefer descriptive PascalCase for classes, lowerCamelCase for methods and variables, and SCREAMING_SNAKE_CASE for compile-time constants. UI widgets should remain stateless where feasible and rely on Provider-managed state.

## Testing Guidelines
All tests use `flutter_test` under `test/`. Create new files mirroring the module under test (for example, `lib/services/paraphrase_service.dart` pairs with `test/services/paraphrase_service_test.dart`). Name test groups with the subject and scenario, and describe expectations in the present tense. Run the suite with `flutter test` before every PR; collect coverage with `flutter test --coverage` when measuring impact.

## Commit & Pull Request Guidelines
Keep commits focused and written in the imperative mood (e.g., `Add clipboard fallback`). Reference related docs or follow-ups in the body when necessary. Pull requests should include: a concise summary of changes, screenshots or screencasts for UI updates, relevant issue links, and notes on macOS/Windows/Linux verification when applicable. Leave TODOs only when accompanied by a tracking issue.

## Security & Configuration Tips
Never commit API keys; rely on secure storage and local `.env` files kept out of version control. Document new configuration flags in `README.md` or `USER_GUIDE.md`, and update installer scripts if security-sensitive defaults change.
