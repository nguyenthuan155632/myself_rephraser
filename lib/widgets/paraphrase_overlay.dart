import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/paraphrase.dart';
import '../core/paraphrase_provider.dart';
import '../services/clipboard_service.dart';
import 'paraphrase_result_card.dart';

class ParaphraseOverlay extends StatefulWidget {
  const ParaphraseOverlay({super.key});

  @override
  State<ParaphraseOverlay> createState() => _ParaphraseOverlayState();
}

class _ParaphraseOverlayState extends State<ParaphraseOverlay> {
  final TextEditingController _textController = TextEditingController();
  ParaphraseMode _selectedMode = ParaphraseMode.formal;
  bool _isProcessing = false;
  ParaphraseResponse? _lastResponse;
  String? _errorMessage;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParaphraseProvider>(
      builder: (context, provider, child) {
        return Material(
          color: Colors.transparent,
          child: Container(
            width: 550,
            constraints: const BoxConstraints(
              minWidth: 500,
              maxWidth: 600,
              minHeight: 450,
              maxHeight: 550,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _isProcessing
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Processing...', style: TextStyle(fontSize: 16)),
                                Text('Please wait...', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          )
                        : _lastResponse != null
                            ? _buildResultView(_lastResponse!)
                            : _buildInputView(provider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Text Rephraser',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ParaphraseProvider provider) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _isProcessing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing...', style: TextStyle(fontSize: 16)),
                    Text('Please wait...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            : _lastResponse != null
                ? _buildResultView(_lastResponse!)
                : _buildInputView(provider),
      ),
    );
  }

  Widget _buildInputView(ParaphraseProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter text to paraphrase:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          maxLines: null,
          expands: false,
          decoration: InputDecoration(
            hintText: 'Paste or type your text here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ParaphraseMode>(
          value: _selectedMode,
          onChanged: (mode) {
            if (mode != null) {
              setState(() {
                _selectedMode = mode;
              });
            }
          },
          decoration: InputDecoration(
            labelText: 'Paraphrase Mode',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          items: ParaphraseMode.values.map((mode) {
            return DropdownMenuItem(
              value: mode,
              child: Text(mode.displayName),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_textController.text.trim().isNotEmpty) {
                _startParaphrasing(provider);
              }
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Paraphrase Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(ParaphraseResponse response) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Success!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              tooltip: 'New paraphrase',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: ParaphraseResultCard(response: response),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(ParaphraseResponse response) {
    return ParaphraseResultCard(response: response);
  }

  Future<void> _startParaphrasing(ParaphraseProvider provider) async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await provider.paraphraseText(_textController.text, _selectedMode);
      setState(() {
        _lastResponse = provider.lastResponse;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _textController.clear();
      _lastResponse = null;
      _errorMessage = null;
      _isProcessing = false;
    });
  }
}