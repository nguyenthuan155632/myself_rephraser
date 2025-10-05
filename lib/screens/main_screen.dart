import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/paraphrase_provider.dart';
import '../widgets/settings_screen.dart';
import '../services/system_integration_service.dart';
import '../services/window_manager_service.dart';
import '../services/clipboard_service.dart';
import '../models/paraphrase.dart';
import 'dart:math' as math;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  @override
  void initState() {
    super.initState();
    WindowManagerService.instance.initialize();
    _initializeApp();
  }

  @override
  void dispose() {
    WindowManagerService.instance.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    print('MainScreen: Starting app initialization...');
    final provider = context.read<ParaphraseProvider>();
    await provider.initialize();
    
    if (mounted) {
      try {
        await SystemIntegrationService.initialize(context);
      } catch (e) {
        print('MainScreen: System integration failed: $e');
      }
    }
    
    print('MainScreen: App initialization completed');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParaphraseProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Myself Rephraser',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-powered text paraphrasing',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  if (provider.settings.apiKey == null || 
                      provider.settings.apiKey!.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'API Key Required',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please configure your OpenRouter API key to start using the app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ready to Use',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use ${provider.settings.globalHotkey} to open the paraphraser overlay',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Settings'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Show about dialog
                        showAboutDialog(
                          context: context,
                          applicationName: 'Myself Rephraser',
                          applicationVersion: '1.0.0',
                          children: [
                            const Text('AI-powered text paraphrasing for desktop'),
                          ],
                        );
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('About'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      WindowManagerService.instance.hideToSystemTray();
                    },
                    child: const Text('Minimize Window'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _showQuitConfirmation();
                    },
                    child: const Text('Quit Application'),
                  ),
                ],
              ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void onWindowClose() async {
    // Minimize instead of closing - prevents app termination
    await WindowManagerService.instance.hideToSystemTray();
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Application'),
        content: const Text('Are you sure you want to quit? The app will no longer be available in the system tray.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              WindowManagerService.instance.quitApplication();
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }
}