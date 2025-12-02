// lib/config/url_config.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// 웹 환경에서만 dart:html import
import 'package:universal_html/html.dart' as html;

class UrlConfig {
  // ========================================================================
  // 🔹 ngrok URL 설정 (배포 환경)
  // ========================================================================

  // ✅ Spring Boot
  static const String? _springBootNgrokUrl =
      'https://semiconical-shela-loftily.ngrok-free.dev';

  // ❗ 기존 FastAPI (OCR, 레벨테스트)
  static const String? _fastApiNgrokUrl =
      'https://cibarian-unmeditatively-rosalina.ngrok-free.dev';

  // ⭐ 신규: FastAPI (채팅 + 팟캐스트 전용)
  static const String _fastApiChatPodcastNgrokUrl =
      'https://dexter-unimitable-deloras.ngrok-free.dev';

  static const int _springBootLocalPort = 8080;

  // ========================================================================
  // 🔹 환경 감지
  // ========================================================================

  static bool get _isLocalhost {
    if (!kIsWeb) return false;

    try {
      final origin = html.window.location.origin;
      return origin?.contains('localhost') == true ||
          origin?.contains('127.0.0.1') == true ||
          origin?.contains('0.0.0.0') == true;
    } catch (e) {
      return false;
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
  // 🔹 Bingo WebSocket URL
  // ========================================================================

  static String get springBootWebSocketUrl {
    final base = _springBootNgrokUrl!;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://') + '/ws/match';
    } else {
      return base.replaceFirst('http://', 'ws://') + '/ws/match';
    }
  }

  // ========================================================================
  // 🔹 Speed WebSocket URL
  // ========================================================================

  static String get springBootSpeedWebSocketUrl {
    final base = _springBootNgrokUrl!;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://') + '/ws/speed';
    } else {
      return base.replaceFirst('http://', 'ws://') + '/ws/speed';
    }
  }

  // ========================================================================
  // 🔹 FastAPI Base URL (OCR, 레벨 테스트)
  // ========================================================================

  static String get fastApiBaseUrl {
    return _fastApiNgrokUrl!;
  }

  // ========================================================================
  // 🔹 ⭐ FastAPI Base URL (채팅 + 팟캐스트 전용)
  // ========================================================================

  static String get fastApiChatPodcastBaseUrl {
    return _fastApiChatPodcastNgrokUrl;
  }

  // ========================================================================
  // 🔹 일반 엔드포인트 헬퍼
  // ========================================================================

  static String springBootEndpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$springBootBaseUrl$normalized';
  }

  static String fastApiEndpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$fastApiBaseUrl$normalized';
  }

  // ⭐ 채팅/팟캐스트 전용 헬퍼
  static String fastApiChatPodcastEndpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$fastApiChatPodcastBaseUrl$normalized';
  }
}
