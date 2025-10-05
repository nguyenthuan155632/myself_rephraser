import 'package:flutter/material.dart';

class MousePositionService {
  static Offset getMousePosition() {
    try {
      // Get screen dimensions
      final screenSize = WidgetsBinding.instance.window.physicalSize;
      final screenRatio = WidgetsBinding.instance.window.devicePixelRatio;
      
      final screenWidth = screenSize.width / screenRatio;
      final screenHeight = screenSize.height / screenRatio;
      
      // Return a reasonable position (upper-right area)
      final centerX = screenWidth * 0.75;
      final centerY = screenHeight * 0.25;
      
      return Offset(centerX, centerY);
    } catch (e) {
      // Safe fallback
      return const Offset(600, 200);
    }
  }
}