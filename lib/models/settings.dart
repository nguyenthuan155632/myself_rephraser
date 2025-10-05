class AppSettings {
  final String? apiKey;
  final String selectedModel;
  final String globalHotkey;
  final bool isDarkMode;
  final double fontSize;
  final bool startAtLogin;

  const AppSettings({
    this.apiKey,
    this.selectedModel = 'google/gemini-2.5-flash-lite-preview-09-2025',
    this.globalHotkey = 'Cmd+Shift+K',
    this.isDarkMode = false,
    this.fontSize = 14.0,
    this.startAtLogin = false,
  });

  AppSettings copyWith({
    String? apiKey,
    String? selectedModel,
    String? globalHotkey,
    bool? isDarkMode,
    double? fontSize,
    bool? startAtLogin,
  }) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? this.selectedModel,
      globalHotkey: globalHotkey ?? this.globalHotkey,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      fontSize: fontSize ?? this.fontSize,
      startAtLogin: startAtLogin ?? this.startAtLogin,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'selectedModel': selectedModel,
    'globalHotkey': globalHotkey,
    'isDarkMode': isDarkMode,
    'fontSize': fontSize,
    'startAtLogin': startAtLogin,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    apiKey: json['apiKey'],
    selectedModel: json['selectedModel'] ?? 'google/gemini-2.5-flash-lite-preview-09-2025',
    globalHotkey: json['globalHotkey'] ?? 'Cmd+Shift+K',
    isDarkMode: json['isDarkMode'] ?? false,
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
    startAtLogin: json['startAtLogin'] ?? false,
  );
}

class AvailableModel {
  final String id;
  final String name;
  final String description;

  const AvailableModel({
    required this.id,
    required this.name,
    required this.description,
  });
}

const List<AvailableModel> availableModels = [
  AvailableModel(
    id: 'google/gemini-2.5-flash-lite-preview-09-2025',
    name: 'Gemini 2.5 Flash Lite',
    description: 'Fast and efficient with latest Gemini capabilities',
  ),
  AvailableModel(
    id: 'gpt-3.5-turbo',
    name: 'GPT-3.5 Turbo',
    description: 'Fast and cost-effective for most paraphrasing tasks',
  ),
  AvailableModel(
    id: 'gpt-4',
    name: 'GPT-4',
    description: 'Higher quality results with better understanding',
  ),
  AvailableModel(
    id: 'claude-3-haiku',
    name: 'Claude 3 Haiku',
    description: 'Fast and efficient with good reasoning',
  ),
  AvailableModel(
    id: 'claude-3-sonnet',
    name: 'Claude 3 Sonnet',
    description: 'Balance between speed and quality',
  ),
];