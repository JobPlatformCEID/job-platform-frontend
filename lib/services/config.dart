import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';      // Android emulator
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return 'http://localhost:8000';      // Desktop
      case TargetPlatform.iOS:
        return 'http://localhost:8000';      // iOS simulator
      default:
        return 'http://localhost:8000';
    }
  }

  static String get wsUrl {
    if (kIsWeb) {
      return 'ws://localhost:8001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ws://10.0.2.2:8001';        // Android emulator
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return 'ws://localhost:8001';        // Desktop
      case TargetPlatform.iOS:
        return 'ws://localhost:8001';        // iOS simulator
      default:
        return 'ws://localhost:8001';
    }
  }
}