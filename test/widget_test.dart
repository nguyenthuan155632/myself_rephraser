import 'package:flutter_test/flutter_test.dart';

import 'package:myself_rephraser/main.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the main screen loads
    expect(find.text('Myself Rephraser'), findsOneWidget);
    expect(find.text('AI-powered text paraphrasing'), findsOneWidget);
  });

  testWidgets('Settings button is present', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Find the Settings button
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('About button is present', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Find the About button
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('Shows API key required message when no API key is set', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Should show the API key required message
    expect(find.text('API Key Required'), findsOneWidget);
    expect(find.text('Please configure your OpenRouter API key to start using the app.'), findsOneWidget);
  });

  testWidgets('Can navigate to settings', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap the Settings button
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Should be on settings screen now
    expect(find.text('API Configuration'), findsOneWidget);
    expect(find.text('OpenRouter API Key'), findsOneWidget);
  });
}