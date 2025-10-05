import 'package:flutter_test/flutter_test.dart';
import 'package:myself_rephraser/models/paraphrase.dart';
import 'package:myself_rephraser/models/settings.dart';

void main() {
  group('ParaphraseMode Tests', () {
    test('ParaphraseMode has correct display names', () {
      expect(ParaphraseMode.formal.displayName, 'Formal');
      expect(ParaphraseMode.simple.displayName, 'Simple');
      expect(ParaphraseMode.shorten.displayName, 'Shorten');
      expect(ParaphraseMode.creative.displayName, 'Creative');
    });

    test('ParaphraseMode has descriptions', () {
      expect(ParaphraseMode.formal.description, isNotEmpty);
      expect(ParaphraseMode.simple.description, isNotEmpty);
      expect(ParaphraseMode.shorten.description, isNotEmpty);
      expect(ParaphraseMode.creative.description, isNotEmpty);
    });
  });

  group('AppSettings Tests', () {
    test('AppSettings default values are correct', () {
      const settings = AppSettings();
      
      expect(settings.apiKey, isNull);
      expect(settings.selectedModel, 'gpt-3.5-turbo');
      expect(settings.globalHotkey, 'Cmd+Shift+P');
      expect(settings.isDarkMode, false);
      expect(settings.fontSize, 14.0);
      expect(settings.startAtLogin, false);
    });

    test('AppSettings copyWith works correctly', () {
      const settings = AppSettings(selectedModel: 'gpt-4');
      final newSettings = settings.copyWith(isDarkMode: true);
      
      expect(newSettings.selectedModel, 'gpt-4');
      expect(newSettings.isDarkMode, true);
      expect(newSettings.fontSize, 14.0);
    });

    test('AppSettings serialization works', () {
      const settings = AppSettings(
        selectedModel: 'claude-3-sonnet',
        isDarkMode: true,
      );
      
      final json = settings.toJson();
      final fromJson = AppSettings.fromJson(json);
      
      expect(fromJson.selectedModel, settings.selectedModel);
      expect(fromJson.isDarkMode, settings.isDarkMode);
    });
  });

  group('Available Models Tests', () {
    test('Available models list is not empty', () {
      expect(availableModels, isNotEmpty);
    });

    test('Each model has required fields', () {
      for (final model in availableModels) {
        expect(model.id, isNotEmpty);
        expect(model.name, isNotEmpty);
        expect(model.description, isNotEmpty);
      }
    });
  });
}