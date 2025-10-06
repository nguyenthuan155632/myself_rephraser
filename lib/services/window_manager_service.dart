import 'package:window_manager/window_manager.dart';

class WindowManagerService extends WindowListener {
  static WindowManagerService? _instance;
  static WindowManagerService get instance =>
      _instance ??= WindowManagerService._();

  WindowManagerService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    windowManager.addListener(this);
    _isInitialized = true;
  }

  @override
  void onWindowClose() async {
    // Hide instead of close when user tries to close the window
    await hideToSystemTray();
  }

  @override
  void onWindowMinimize() async {
    // Hide to system tray when minimized
    await hideToSystemTray();
  }

  Future<void> hideToSystemTray() async {
    try {
      print('WindowManagerService: Hiding to system tray...');

      // Instead of hiding completely, just minimize and move to back
      await windowManager.minimize();

      print('WindowManagerService: Window minimized (app stays running)');
    } catch (e) {
      print('WindowManagerService: Failed to minimize window: $e');
    }
  }

  Future<void> showFromSystemTray() async {
    try {
      print('WindowManagerService: Showing window from system tray...');
      await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
      print('WindowManagerService: Window shown successfully');
    } catch (e) {
      print('WindowManagerService: Failed to show window: $e');
    }
  }

  Future<void> maximizeWindow() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      if (isMaximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (e) {
      print('WindowManagerService: Failed to maximize/restore window: $e');
    }
  }

  Future<bool> isMaximized() async {
    try {
      return await windowManager.isMaximized();
    } catch (e) {
      print('WindowManagerService: Failed to check maximize state: $e');
      return false;
    }
  }

  Future<void> quitApplication() async {
    windowManager.removeListener(this);
    await windowManager.destroy();
  }

  void dispose() {
    windowManager.removeListener(this);
    _isInitialized = false;
  }
}
