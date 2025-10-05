import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import '../widgets/paraphrase_overlay.dart';
import 'window_manager_service.dart';
import 'mouse_position_service.dart';
import 'clipboard_service.dart';

class SystemIntegrationService {
  static SystemTray? _systemTray;
  static HotKey? _hotKey;
  static bool _initialized = false;
  static BuildContext? _appContext; // Store app context for overlay
  static bool _isOverlayVisible = false;

  static Future<void> initialize(BuildContext context) async {
    print(
      'SystemIntegrationService: Initialize called (initialized: $_initialized)',
    );

    // Always update context for hot restart compatibility
    _appContext = context;

    // If already initialized, just ensure hotkey is registered
    if (_initialized) {
      print('SystemIntegrationService: Re-registering after restart');
      await _ensureHotkeyRegistered(context);
      return;
    }

    print('SystemIntegrationService: First-time initialization');

    // Get the context safely for system tray setup
    if (context.mounted) {
      // Set up global hotkey first (essential functionality)
      await _setupGlobalHotkey(context);

      // System tray is optional - don't let it block startup
      try {
        await _setupSystemTray(context);
      } catch (e) {
        print('System tray setup failed (app will still work): $e');
        // Continue without system tray
      }
    }

    _initialized = true;
    print('SystemIntegrationService: Initialization complete');
  }

  static Future<void> _ensureHotkeyRegistered(BuildContext context) async {
    try {
      // Unregister old hotkey if exists
      if (_hotKey != null) {
        await hotKeyManager.unregister(_hotKey!);
      }
      // Re-register the hotkey
      await _setupGlobalHotkey(context);
    } catch (e) {
      print('Error re-registering hotkey: $e');
    }
  }

  static Future<void> _setupSystemTray(BuildContext context) async {
    try {
      _systemTray = SystemTray();

      // Try to initialize system tray
      try {
        await _systemTray?.initSystemTray(iconPath: 'assets/tray_icon.png');
      } catch (e) {
        print('SystemIntegrationService: Icon initialization failed: $e');
        // Try with ICO as fallback
        try {
          await _systemTray?.initSystemTray(iconPath: 'assets/app_icon.ico');
          print(
            'SystemIntegrationService: System tray initialized with fallback icon',
          );
        } catch (e2) {
          print('SystemIntegrationService: All icon attempts failed: $e2');
          // Try without icon
          return;
        }
      }

      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Show',
          onClicked: (menuItem) =>
              WindowManagerService.instance.showFromSystemTray(),
        ),
        MenuItemLabel(
          label: 'Settings',
          onClicked: (menuItem) {
            if (context.mounted) _showSettings(context);
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Quit',
          onClicked: (menuItem) =>
              WindowManagerService.instance.quitApplication(),
        ),
      ]);

      await _systemTray?.setContextMenu(menu);

      _systemTray?.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          WindowManagerService.instance.showFromSystemTray();
        }
      });

      print('System tray initialized successfully');
    } catch (e) {
      print('System tray setup failed: $e');
    }
  }

  static Future<void> _setupGlobalHotkey(BuildContext context) async {
    try {
      print(
        'SystemIntegrationService: Setting up global hotkey (Cmd+Shift+K)...',
      );

      // Unregister all existing hotkeys first (important for hot restart)
      try {
        await hotKeyManager.unregisterAll();
        print('SystemIntegrationService: Cleared existing hotkeys');
      } catch (e) {
        print('SystemIntegrationService: No existing hotkeys to clear: $e');
      }

      // Default hotkey will be set from settings
      _hotKey = HotKey(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );

      await hotKeyManager.register(
        _hotKey!,
        keyDownHandler: (hotKey) {
          print('SystemIntegrationService: Hotkey pressed!');
          if (_appContext != null && _appContext!.mounted) {
            _toggleParaphraseOverlay(_appContext!);
          } else {
            print('SystemIntegrationService: Context not available');
          }
        },
      );

      print('SystemIntegrationService: Global hotkey registered successfully');
    } catch (e) {
      print('SystemIntegrationService: Failed to register hotkey: $e');
    }
  }

  static Future<void> updateHotkey(
    String hotkeyString,
    BuildContext context,
  ) async {
    if (_hotKey != null) {
      await hotKeyManager.unregister(_hotKey!);
    }

    // Parse hotkey string and register new hotkey
    // This is a simplified version - you'd want to parse the string properly
    _hotKey = HotKey(
      key: PhysicalKeyboardKey.keyK,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      _hotKey!,
      keyDownHandler: (hotKey) {
        if (_appContext != null && _appContext!.mounted) {
          _showParaphraseOverlay(_appContext!);
        }
      },
    );
  }

  static void _showSettings(BuildContext context) {
    WindowManagerService.instance.showFromSystemTray();
    // Navigate to settings screen
    if (context.mounted) {
      Navigator.of(context).pushNamed('/settings');
    }
  }

  static void _toggleParaphraseOverlay(BuildContext context) async {
    if (_isOverlayVisible) {
      print(
        'SystemIntegrationService: Overlay already open, bringing to foreground',
      );
      // Just bring window to foreground, don't close the overlay
      await WindowManagerService.instance.showFromSystemTray();
    } else {
      print('SystemIntegrationService: Opening overlay');
      // Bring window to foreground first
      await WindowManagerService.instance.showFromSystemTray();
      _showParaphraseOverlay(context);
    }
  }

  static void _showParaphraseOverlay(BuildContext context) async {
    try {
      // Get clipboard text (user should copy first with Cmd+C)
      String? clipboardText;
      try {
        clipboardText = await ClipboardService.getClipboardText();
        if (clipboardText != null && clipboardText.isNotEmpty) {
          print(
            'SystemIntegrationService: Clipboard text: ${clipboardText.substring(0, clipboardText.length > 50 ? 50 : clipboardText.length)}...',
          );
        } else {
          print('SystemIntegrationService: Clipboard is empty');
        }
      } catch (e) {
        print('SystemIntegrationService: Failed to get clipboard: $e');
      }

      // Get mouse cursor position
      final mousePosition = MousePositionService.getMousePosition();

      const overlayWidth = 1200.0;
      const overlayHeight = 900.0;

      // Get screen dimensions with safe defaults
      double screenWidth = 1920.0;
      double screenHeight = 1080.0;

      try {
        final screenSize = MediaQuery.of(context).size;
        if (screenSize.width > 100 && screenSize.height > 100) {
          screenWidth = screenSize.width;
          screenHeight = screenSize.height;
        }
      } catch (e) {
        print('SystemIntegrationService: Using default screen size');
      }

      // Calculate position without clamp to avoid the error
      double left = mousePosition.dx - overlayWidth / 2;
      double top = mousePosition.dy - overlayHeight / 2;

      // Ensure position stays within bounds using simple math
      if (left < 0) left = 0;
      if (left > screenWidth - overlayWidth) left = screenWidth - overlayWidth;
      if (top < 0) top = 0;
      if (top > screenHeight - overlayHeight)
        top = screenHeight - overlayHeight;

      print(
        'SystemIntegrationService: Showing overlay at (${left.toInt()}, ${top.toInt()})',
      );

      _isOverlayVisible = true;

      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: overlayWidth,
                  height: overlayHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ParaphraseOverlay(initialText: clipboardText),
                ),
              ),
            ],
          ),
        ),
      ).then((_) {
        _isOverlayVisible = false;
      });
    } catch (e) {
      print('SystemIntegrationService: Error showing overlay: $e');
      // Fallback to centered overlay
      _showCenteredOverlay(context);
    }
  }

  static void _showCenteredOverlay(BuildContext context) async {
    _isOverlayVisible = true;

    // Get clipboard text
    String? clipboardText;
    try {
      clipboardText = await ClipboardService.getClipboardText();
    } catch (e) {
      print('SystemIntegrationService: Failed to get clipboard: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ParaphraseOverlay(initialText: clipboardText),
      ),
    ).then((_) {
      _isOverlayVisible = false;
    });
  }

  static void dispose() async {
    await hotKeyManager.unregisterAll();
    await _systemTray?.destroy();
  }
}
