import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/paraphrase_provider.dart';
import '../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _hotkeyController = TextEditingController();
  
  String _selectedModel = 'gpt-3.5-turbo';
  bool _isDarkMode = false;
  double _fontSize = 14.0;
  bool _startAtLogin = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _loadSettings();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _hotkeyController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final provider = context.read<ParaphraseProvider>();
    final settings = provider.settings;
    
    _apiKeyController.text = settings.apiKey ?? '';
    _hotkeyController.text = settings.globalHotkey;
    _selectedModel = settings.selectedModel;
    _isDarkMode = settings.isDarkMode;
    _fontSize = settings.fontSize;
    _startAtLogin = settings.startAtLogin;
  }

  Future<void> _saveSettings() async {
    try {
      final provider = context.read<ParaphraseProvider>();
      
      print('Saving settings...');
      print('API Key: ${_apiKeyController.text.trim().isNotEmpty ? "SET" : "EMPTY"}');
      print('Model: $_selectedModel');
      
      final newSettings = provider.settings.copyWith(
        apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
        selectedModel: _selectedModel,
        globalHotkey: _hotkeyController.text,
        isDarkMode: _isDarkMode,
        fontSize: _fontSize,
        startAtLogin: _startAtLogin,
      );

      await provider.updateSettings(newSettings);
      
      print('Settings saved successfully!');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildApiSection(),
            const SizedBox(height: 24),
            _buildShortcutsSection(),
            const SizedBox(height: 24),
            _buildAppearanceSection(),
            const SizedBox(height: 24),
            _buildAdvancedSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'OpenRouter API Key',
                hintText: 'Enter your OpenRouter API key',
                border: OutlineInputBorder(),
                helperText: 'Get your API key from openrouter.ai',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedModel,
                decoration: const InputDecoration(
                  labelText: 'AI Model',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: availableModels.map((model) {
                  return DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(
                      model.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedModel = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              availableModels.firstWhere((model) => model.id == _selectedModel).description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shortcuts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hotkeyController,
              decoration: const InputDecoration(
                labelText: 'Global Hotkey',
                hintText: 'e.g., Cmd+Shift+P',
                border: OutlineInputBorder(),
                helperText: 'Hotkey to open the paraphraser overlay',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme'),
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                });
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Font Size'),
              subtitle: Slider(
                value: _fontSize,
                min: 10.0,
                max: 20.0,
                divisions: 10,
                label: '${_fontSize.toInt()}px',
                onChanged: (value) {
                  setState(() {
                    _fontSize = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Start at Login'),
              subtitle: const Text('Launch app when system starts'),
              value: _startAtLogin,
              onChanged: (value) {
                setState(() {
                  _startAtLogin = value;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Implement clear cache
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared')),
                  );
                },
                child: const Text('Clear Cache'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}