enum ParaphraseMode {
  formal('Formal', 'Transform casual text into a professional tone'),
  simple('Simple', 'Simplify complex sentences for clarity'),
  shorten('Shorten', 'Reduce length while preserving meaning'),
  creative('Creative', 'Generate expressive and varied rewrites');

  const ParaphraseMode(this.displayName, this.description);
  final String displayName;
  final String description;
}

enum ParaphraseStatus { idle, processing, success, error }

class ParaphraseRequest {
  final String text;
  final ParaphraseMode mode;
  final String model;

  const ParaphraseRequest({
    required this.text,
    required this.mode,
    required this.model,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'mode': mode.name,
    'model': model,
  };
}

class ParaphraseResponse {
  final String originalText;
  final List<String> paraphrasedOptions;
  final ParaphraseMode mode;
  final String model;
  final DateTime timestamp;

  const ParaphraseResponse({
    required this.originalText,
    required this.paraphrasedOptions,
    required this.mode,
    required this.model,
    required this.timestamp,
  });

  // Backward compatibility
  String get paraphrasedText =>
      paraphrasedOptions.isNotEmpty ? paraphrasedOptions.first : '';
}
