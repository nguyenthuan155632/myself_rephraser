import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/paraphrase.dart';
import '../models/settings.dart';

class OpenRouterService {
  static const String baseUrl = 'https://openrouter.ai/api/v1';

  final String _apiKey;
  final String _model;

  OpenRouterService({required String apiKey, required String model})
    : _apiKey = apiKey,
      _model = model;

  Future<ParaphraseResponse> paraphraseText(
    String text,
    ParaphraseMode mode,
  ) async {
    if (_apiKey.isEmpty) {
      throw Exception('API key is required');
    }

    final prompt = _buildPrompt(text, mode);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://myself-rephraser.app',
          'X-Title': 'Myself Rephraser',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Parse the response to extract individual options
        final paraphrasedOptions = _parseOptions(content.trim());

        return ParaphraseResponse(
          originalText: text,
          paraphrasedOptions: paraphrasedOptions,
          mode: mode,
          model: _model,
          timestamp: DateTime.now(),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error']['message'] ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: ${e.toString()}');
    }
  }

  List<String> _parseOptions(String content) {
    // Try to split by numbered options (1., 2., 3. or 1), 2), 3))
    final numberedPattern = RegExp(
      r'(?:^|\n)(?:\d+[\.\)])\s*(.+?)(?=\n\d+[\.\)]|\$)',
      multiLine: true,
      dotAll: true,
    );
    final numberedMatches = numberedPattern.allMatches(content);

    if (numberedMatches.length >= 3) {
      return numberedMatches
          .take(3)
          .map((m) => _cleanOption(m.group(1)!))
          .toList();
    }

    // Try to split by bullet points or asterisks
    final bulletPattern = RegExp(
      r'(?:^|\n)[\*\-•]\s*(.+?)(?=\n[\*\-•]|\$)',
      multiLine: true,
      dotAll: true,
    );
    final bulletMatches = bulletPattern.allMatches(content);

    if (bulletMatches.length >= 3) {
      return bulletMatches
          .take(3)
          .map((m) => _cleanOption(m.group(1)!))
          .toList();
    }

    // Try splitting by "Option N:" pattern
    final optionPattern = RegExp(
      r'(?:Option|Alternative)\s*\d+:?\s*(.+?)(?=(?:Option|Alternative)\s*\d+:?|\$)',
      multiLine: true,
      dotAll: true,
      caseSensitive: false,
    );
    final optionMatches = optionPattern.allMatches(content);

    if (optionMatches.length >= 3) {
      return optionMatches
          .take(3)
          .map((m) => _cleanOption(m.group(1)!))
          .toList();
    }

    // Fallback: split by double newlines
    final parts = content
        .split(RegExp(r'\n\s*\n+'))
        .where((p) => p.trim().isNotEmpty)
        .map((p) => _cleanOption(p))
        .toList();

    if (parts.length >= 3) {
      return parts.take(3).toList();
    }

    // Last resort: return the whole content as single option
    return [_cleanOption(content)];
  }

  String _cleanOption(String text) {
    // Remove leading numbers (1., 2., 1), 2), etc)
    text = text.replaceFirst(RegExp(r'^\s*\d+[\.\)]\s*'), '');
    // Remove leading bullets
    text = text.replaceFirst(RegExp(r'^\s*[\*\-•]\s*'), '');
    // Remove leading "Option N:" or "Alternative N:"
    text = text.replaceFirst(
      RegExp(r'^\s*(?:Option|Alternative)\s*\d+:?\s*', caseSensitive: false),
      '',
    );
    return text.trim();
  }

  String _buildPrompt(String text, ParaphraseMode mode) {
    switch (mode) {
      case ParaphraseMode.formal:
        return '''Rephrase the following text in a formal, professional tone suitable for business communication, academic writing, or official documents.

REQUIREMENTS:
- Provide exactly 3 different versions
- Use sophisticated vocabulary and professional language
- Maintain the original meaning precisely
- Each version should be 100-120% of the original length
- Use proper grammar and formal sentence structure
- Avoid contractions and casual expressions

Format your response as:
1. [First formal version]

2. [Second formal version]

3. [Third formal version]

Original text: "$text"''';

      case ParaphraseMode.simple:
        return '''Simplify the following text to make it easier to understand while keeping the same meaning.

REQUIREMENTS:
- Provide exactly 3 different simplified versions
- Use common, everyday words
- Break complex sentences into shorter ones
- Maintain clarity and readability
- Each version should be 90-110% of the original length
- Keep the core message intact

Format your response as:
1. [First simplified version]

2. [Second simplified version]

3. [Third simplified version]

Original text: "$text"''';

      case ParaphraseMode.shorten:
        return '''Create concise versions of the following text by removing unnecessary words while preserving the essential meaning.

REQUIREMENTS:
- Provide exactly 3 different shortened versions
- Remove redundant words and filler phrases
- Combine ideas efficiently
- Keep all critical information
- Each version should be 60-80% of the original length
- Maintain clarity despite brevity

Format your response as:
1. [First shortened version]

2. [Second shortened version]

3. [Third shortened version]

Original text: "$text"''';

      case ParaphraseMode.creative:
        return '''Rephrase the following text in creative and engaging ways while maintaining its meaning.

REQUIREMENTS:
- Provide exactly 3 different creative versions
- Use vivid vocabulary and varied expressions
- Employ different sentence structures and styles
- Make it engaging and interesting to read
- Each version should be 90-120% of the original length
- Preserve the original message and tone

Format your response as:
1. [First creative version]

2. [Second creative version]

3. [Third creative version]

Original text: "$text"''';
    }
  }

  static Future<List<AvailableModel>> getAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['data'] as List;

        return models
            .where(
              (model) =>
                  (model['id'] as String).contains('gpt') ||
                  (model['id'] as String).contains('claude'),
            )
            .map(
              (model) => AvailableModel(
                id: model['id'] as String,
                name: model['name'] as String,
                description: model['description'] as String? ?? '',
              ),
            )
            .toList();
      }
    } catch (e) {
      // Return default models if API call fails
      return availableModels;
    }

    return availableModels;
  }
}
