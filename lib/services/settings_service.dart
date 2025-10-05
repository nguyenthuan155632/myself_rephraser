import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _apiKeyPrefsKey = 'api_key_fallback';

  Future<AppSettings> loadSettings() async {
    try {
      print('SettingsService: Loading settings...');
      final prefs = await SharedPreferences.getInstance();

      // Check fallback storage first (more reliable)
      String? apiKey = prefs.getString(_apiKeyPrefsKey);
      bool usedFallback = false;

      // If fallback is empty, try secure storage
      if (apiKey == null || apiKey.isEmpty) {
        try {
          apiKey = await _secureStorage.read(key: 'api_key');
          if (apiKey != null && apiKey.isNotEmpty) {
            print('SettingsService: Loaded API key from secure storage');
            // Save to fallback for next time
            await prefs.setString(_apiKeyPrefsKey, apiKey);
          }
        } catch (e) {
          print('SettingsService: Secure storage read failed: $e');
        }
      } else {
        usedFallback = true;
        print('SettingsService: Loaded API key from fallback storage');
      }

      final selectedModel =
          prefs.getString('selected_model') ??
          'google/gemini-2.5-flash-lite-preview-09-2025';
      final globalHotkey = prefs.getString('global_hotkey') ?? 'Cmd+Shift+K';
      final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      final defaultParaphraseMode =
          prefs.getString('default_paraphrase_mode') ?? 'formal';

      print(
        'SettingsService: API Key is ${apiKey != null && apiKey.isNotEmpty ? "SET" : "NULL"}',
      );
      if (usedFallback) {
        print('SettingsService: (Using fallback storage)');
      }
      print('SettingsService: Model: $selectedModel');

      return AppSettings(
        apiKey: (apiKey != null && apiKey.isNotEmpty) ? apiKey : null,
        selectedModel: selectedModel,
        globalHotkey: globalHotkey,
        isDarkMode: isDarkMode,
        defaultParaphraseMode: defaultParaphraseMode,
      );
    } catch (e) {
      print('SettingsService: Error loading settings: $e');
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      print('SettingsService: Saving settings...');
      final prefs = await SharedPreferences.getInstance();

      if (settings.apiKey != null) {
        print('SettingsService: Saving API key...');

        // Always save to both secure storage and fallback
        bool secureStorageSuccess = false;
        try {
          await _secureStorage.write(key: 'api_key', value: settings.apiKey);
          secureStorageSuccess = true;
          print('SettingsService: API key saved to secure storage');
        } catch (e) {
          print('SettingsService: Secure storage failed: $e');
        }

        // Always save to fallback as backup
        await prefs.setString(_apiKeyPrefsKey, settings.apiKey!);
        print('SettingsService: API key saved to fallback storage');

        if (!secureStorageSuccess) {
          print(
            'SettingsService: Note: Using fallback storage due to secure storage issue',
          );
        }
      } else {
        print('SettingsService: API key is null, removing from storage');
        try {
          await _secureStorage.delete(key: 'api_key');
        } catch (e) {
          print('SettingsService: Could not delete from secure storage: $e');
        }
        await prefs.remove(_apiKeyPrefsKey);
      }

      print('SettingsService: Saving regular preferences...');
      await prefs.setString('selected_model', settings.selectedModel);
      await prefs.setString('global_hotkey', settings.globalHotkey);
      await prefs.setBool('is_dark_mode', settings.isDarkMode);
      await prefs.setString(
        'default_paraphrase_mode',
        settings.defaultParaphraseMode,
      );

      print('SettingsService: All settings saved successfully');
    } catch (e) {
      print('SettingsService: Error saving settings: $e');
      throw Exception('Failed to save settings: ${e.toString()}');
    }
  }

  Future<void> clearAllSettings() async {
    try {
      await _secureStorage.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Failed to clear settings: ${e.toString()}');
    }
  }

  Future<bool> hasValidApiKey() async {
    final apiKey = await _secureStorage.read(key: 'api_key');
    return apiKey != null && apiKey.isNotEmpty;
  }
}
