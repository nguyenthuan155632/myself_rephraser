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

        return ParaphraseResponse(
          originalText: text,
          paraphrasedText: content.trim(),
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

  String _buildPrompt(String text, ParaphraseMode mode) {
    switch (mode) {
      case ParaphraseMode.formal:
        return '''Please rephrase the following text in a formal, professional tone. Make it suitable for business communication, academic writing, or formal documents. Maintain the original meaning but use more sophisticated language and structure.

Original text: "$text"

Rephrased text:''';

      case ParaphraseMode.simple:
        return '''Please simplify the following text to make it easier to understand. Use simpler words and shorter sentences. Break down complex ideas into more straightforward concepts while maintaining the original meaning.

Original text: "$text"

Simplified text:''';

      case ParaphraseMode.shorten:
        return '''Please shorten the following text while preserving its core meaning. Remove unnecessary words, combine ideas, and make it more concise. Keep the essential information intact.

Original text: "$text"

Shortened text:''';

      case ParaphraseMode.creative:
        return '''Please rephrase the following text in a more creative and expressive way. Use varied vocabulary, different sentence structures, and engaging language. Make it more interesting to read while maintaining the original meaning.

Original text: "$text"

Creative rephrasing:''';
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
