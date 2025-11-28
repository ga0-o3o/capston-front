// lib/config/url_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;

class UrlConfig {
  // ========================================================================
  // 🔹 ngrok URL 설정 (배포 환경)
  // ========================================================================

  static const String? _springBootNgrokUrl =
      'https://semiconical-shela-loftily.ngrok-free.dev';

  static const String? _fastApiNgrokUrl = null;

  static const int _springBootLocalPort = 8080;
  static const int _fastApiLocalPort = 8000;

  // ========================================================================
  // 🔹 환경 감지
  // ========================================================================

  static bool get _isLocalhost {
    if (!kIsWeb) return true;

    try {
      final origin = html.window.location.origin;
      return origin.contains('localhost') ||
          origin.contains('127.0.0.1') ||
          origin.contains('0.0.0.0');
    } catch (e) {
      return true;
    }
  }

  // ========================================================================
  // 🔹 Spring Boot Base URL
  // ========================================================================

  static String get springBootBaseUrl {
    if (kIsWeb) {
      if (_isLocalhost) {
        return 'http://localhost:$_springBootLocalPort';
      } else {
        return _springBootNgrokUrl ?? 'http://localhost:$_springBootLocalPort';
      }
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_springBootLocalPort';
    }

    return 'http://localhost:$_springBootLocalPort';
  }

  // ========================================================================
  // 🔹 Bingo WebSocket URL (ws://host/ws/match)
  // ========================================================================

  static String get springBootWebSocketUrl {
    final base = springBootBaseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://') + '/ws/match';
    } else {
      return base.replaceFirst('http://', 'ws://') + '/ws/match';
    }
  }

  // ========================================================================
  // 🔹 Speed WebSocket URL (ws://host/ws/speed)
  // ========================================================================

  static String get springBootSpeedWebSocketUrl {
    // ✅ Speed Game은 항상 ngrok URL 사용 (다른 PC 간 매칭을 위해)
    final base = _springBootNgrokUrl ?? 'https://semiconical-shela-loftily.ngrok-free.dev';
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://') + '/ws/speed';
    } else {
      return base.replaceFirst('http://', 'ws://') + '/ws/speed';
    }
  }

  // ========================================================================
  // 🔹 FastAPI Base URL
  // ========================================================================

  static String get fastApiBaseUrl {
    if (kIsWeb) {
      if (_isLocalhost) {
        return 'http://127.0.0.1:$_fastApiLocalPort';
      } else {
        return _fastApiNgrokUrl ?? 'http://127.0.0.1:$_fastApiLocalPort';
      }
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_fastApiLocalPort';
    }

    return 'http://localhost:$_fastApiLocalPort';
  }

  // ========================================================================
  // 🔹 엔드포인트 헬퍼
  // ========================================================================

  static String springBootEndpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$springBootBaseUrl$normalized';
  }

  static String fastApiEndpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$fastApiBaseUrl$normalized';
  }
}
