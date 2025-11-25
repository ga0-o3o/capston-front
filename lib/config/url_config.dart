import 'package:flutter/foundation.dart' show kIsWeb;

class UrlConfig {
  // ============================================================
  //  🔹 1) 네가 사용할 ngrok URL만 적으면 됨
  // ============================================================

  static const String springBootNgrok =
      'https://semiconical-shela-loftily.ngrok-free.dev';

  static const String fastApiNgrok =
      'https://semiconical-shela-loftily.ngrok-free.dev';
  // 필요 없으면 null 가능하지만 일단 동일 URL로

  // ============================================================
  //  🔹 2) HTTP Base URL (무조건 ngrok)
  // ============================================================

  static String get springBootBaseUrl => springBootNgrok;
  static String get fastApiBaseUrl => fastApiNgrok;

  // ============================================================
  //  🔹 3) WebSocket URL (HTTPS → WSS 변환)
  // ============================================================

  static String get springBootWebSocketUrl {
    if (springBootNgrok.startsWith('https://')) {
      return springBootNgrok.replaceFirst('https://', 'wss://') + '/ws/match';
    } else {
      return springBootNgrok.replaceFirst('http://', 'ws://') + '/ws/match';
    }
  }

  // ============================================================
  //  🔹 4) 엔드포인트 헬퍼
  // ============================================================

  static String springBootEndpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$springBootBaseUrl$normalized';
  }

  static String fastApiEndpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$fastApiBaseUrl$normalized';
  }
}
