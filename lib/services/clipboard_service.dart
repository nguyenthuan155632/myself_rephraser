import 'package:flutter/services.dart';

class ClipboardService {
  static Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      throw Exception('Failed to copy to clipboard: ${e.toString()}');
    }
  }

  static Future<String?> getClipboardText() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      return clipboardData?.text;
    } catch (e) {
      throw Exception('Failed to get clipboard text: ${e.toString()}');
    }
  }
}