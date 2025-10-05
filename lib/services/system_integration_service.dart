import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/paraphrase_overlay.dart';
import 'window_manager_service.dart';
import 'mouse_position_service.dart';

class SystemIntegrationService {
  static SystemTray? _systemTray;
  static HotKey? _hotKey;
  static bool _initialized = false;
  static BuildContext? _appContext; // Store app context for overlay

  static Future<void> initialize(BuildContext context) async {
    if (_initialized) return;
    
    // Store app context for overlay use
    _appContext = context;
    
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
  }

  static Future<void> _setupSystemTray(BuildContext context) async {
    try {
      _systemTray = SystemTray();
      
      // Try to initialize system tray
      try {
        await _systemTray?.initSystemTray(
          iconPath: 'assets/tray_icon.png',
        );
      } catch (e) {
        print('SystemIntegrationService: Icon initialization failed: $e');
        // Try with ICO as fallback
        try {
          await _systemTray?.initSystemTray(
            iconPath: 'assets/app_icon.ico',
          );
          print('SystemIntegrationService: System tray initialized with fallback icon');
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
          onClicked: (menuItem) => WindowManagerService.instance.showFromSystemTray(),
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
          onClicked: (menuItem) => WindowManagerService.instance.quitApplication(),
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
    // Default hotkey will be set from settings
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

  static Future<void> updateHotkey(String hotkeyString, BuildContext context) async {
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

  static void _showParaphraseOverlay(BuildContext context) {
    try {
      // Get mouse cursor position
      final mousePosition = MousePositionService.getMousePosition();
      
      const overlayWidth = 600.0;
      const overlayHeight = 400.0;
      
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
      if (top > screenHeight - overlayHeight) top = screenHeight - overlayHeight;
      
      print('SystemIntegrationService: Showing overlay at (${left.toInt()}, ${top.toInt()})');
      
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
                  child: const ParaphraseOverlay(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('SystemIntegrationService: Error showing overlay: $e');
      // Fallback to centered overlay
      _showCenteredOverlay(context);
    }
  }
  
  static void _showCenteredOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: ParaphraseOverlay(),
      ),
    );
  }

  static Offset _getMousePosition() {
    try {
      // This is a simplified approach - in a real implementation you'd use
      // platform-specific APIs to get the actual cursor position
      // For now, we'll use a reasonable default (center of screen)
      return const Offset(200, 200);
    } catch (e) {
      print('Error getting mouse position: $e');
      return const Offset(200, 200);
    }
  }

  static void _exitApp() async {
    await WindowManagerService.instance.quitApplication();
  }

  static void dispose() async {
    await hotKeyManager.unregisterAll();
    await _systemTray?.destroy();
  }
}