import 'package:flutter/foundation.dart';
import '../models/paraphrase.dart';
import '../models/settings.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/clipboard_service.dart';

class ParaphraseProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  
  AppSettings _settings = const AppSettings();
  ParaphraseStatus _status = ParaphraseStatus.idle;
  ParaphraseResponse? _lastResponse;
  String? _errorMessage;
  
  // Getters
  AppSettings get settings => _settings;
  ParaphraseStatus get status => _status;
  ParaphraseResponse? get lastResponse => _lastResponse;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _status == ParaphraseStatus.processing;

  // Initialize settings
  Future<void> initialize() async {
    try {
      _settings = await _settingsService.loadSettings();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load settings: ${e.toString()}');
    }
  }

  // Update settings
  Future<void> updateSettings(AppSettings newSettings) async {
    try {
      print('Provider: Updating settings...');
      print('Provider: API Key is ${newSettings.apiKey != null ? "SET" : "NULL"}');
      print('Provider: Model: ${newSettings.selectedModel}');
      
      await _settingsService.saveSettings(newSettings);
      _settings = newSettings;
      notifyListeners();
      
      print('Provider: Settings updated and notified listeners');
    } catch (e) {
      print('Provider: Error updating settings: $e');
      _setError('Failed to save settings: ${e.toString()}');
      rethrow;
    }
  }

  // Paraphrase text
  Future<void> paraphraseText(String text, ParaphraseMode mode) async {
    if (text.trim().isEmpty) {
      _setError('Please enter some text to paraphrase');
      return;
    }

    if (_settings.apiKey == null || _settings.apiKey!.isEmpty) {
      _setError('Please set your OpenRouter API key in settings');
      return;
    }

    _setStatus(ParaphraseStatus.processing);
    _errorMessage = null;

    try {
      final apiService = OpenRouterService(
        apiKey: _settings.apiKey!,
        model: _settings.selectedModel,
      );

      final response = await apiService.paraphraseText(text, mode);
      
      _lastResponse = response;
      _setStatus(ParaphraseStatus.success);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Copy paraphrased text to clipboard
  Future<void> copyToClipboard() async {
    if (_lastResponse?.paraphrasedText != null) {
      try {
        await ClipboardService.copyToClipboard(_lastResponse!.paraphrasedText);
      } catch (e) {
        _setError('Failed to copy to clipboard: ${e.toString()}');
      }
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Reset status
  void reset() {
    _status = ParaphraseStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void _setStatus(ParaphraseStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _status = ParaphraseStatus.error;
    notifyListeners();
  }
}