// lib/config/url_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;

/// 🌐 중앙 URL 관리 서비스
///
/// Flutter Web의 현재 origin을 감지하여 자동으로 적절한 URL을 반환합니다.
///
/// 동작 방식:
/// - localhost 환경: localhost:8080 (Spring Boot), localhost:8000 (FastAPI)
/// - ngrok/배포 환경: ngrok URL 사용
class UrlConfig {
  // ============================================================================
  // 🔹 고정 URL 설정 (배포 환경용)
  // ============================================================================

  /// Spring Boot ngrok URL (배포 환경에서 사용)
  ///
  /// 💡 배포 시에만 설정하세요. 개발 중에는 null로 두면 자동으로 localhost 사용
  static const String? _springBootNgrokUrl =
      'https://semiconical-shela-loftily.ngrok-free.dev';

  /// FastAPI ngrok URL (배포 환경에서 사용)
  ///
  /// 💡 배포 시에만 설정하세요. 개발 중에는 null로 두면 자동으로 localhost 사용
  static const String? _fastApiNgrokUrl = null;

  /// 로컬 포트 설정
  static const int _springBootLocalPort = 8080;
  static const int _fastApiLocalPort = 8000;

  // ============================================================================
  // 🔹 현재 환경 감지
  // ============================================================================

  /// 현재 Web 환경에서 localhost로 실행 중인지 확인
  static bool get _isLocalhost {
    if (!kIsWeb) return true; // 모바일/데스크톱은 항상 localhost 환경으로 간주

    try {
      final origin = html.window.location.origin;
      return origin.contains('localhost') ||
             origin.contains('127.0.0.1') ||
             origin.contains('0.0.0.0');
    } catch (e) {
      print('[URL_CONFIG] ⚠️ Origin 감지 실패: $e');
      return true; // 실패 시 안전하게 localhost로 간주
    }
  }

  /// 현재 실행 환경 출력 (디버깅용)
  static void printCurrentEnvironment() {
    if (kIsWeb) {
      try {
        final origin = html.window.location.origin;
        print('');
        print('╔════════════════════════════════════════════════════════════');
        print('║ [URL_CONFIG] 🌐 Current Web Environment');
        print('╠════════════════════════════════════════════════════════════');
        print('║ Origin: $origin');
        print('║ Is Localhost: $_isLocalhost');
        print('║ Spring Boot URL: $springBootBaseUrl');
        print('║ FastAPI URL: $fastApiBaseUrl');
        print('╚════════════════════════════════════════════════════════════');
        print('');
      } catch (e) {
        print('[URL_CONFIG] ⚠️ Environment print failed: $e');
      }
    } else {
      print('[URL_CONFIG] 📱 Running on mobile/desktop platform');
    }
  }

  // ============================================================================
  // 🔹 Spring Boot URL 자동 선택
  // ============================================================================

  /// Spring Boot HTTP(S) base URL
  ///
  /// 환경별 자동 선택:
  /// - localhost: http://localhost:8080
  /// - Android: http://10.0.2.2:8080
  /// - ngrok/배포: https://...ngrok-free.dev
  static String get springBootBaseUrl {
    // 1️⃣ Web 환경
    if (kIsWeb) {
      if (_isLocalhost) {
        // localhost 환경
        print('[URL_CONFIG] 🏠 Using localhost for Spring Boot: http://localhost:$_springBootLocalPort');
        return 'http://localhost:$_springBootLocalPort';
      } else {
        // ngrok/배포 환경
        if (_springBootNgrokUrl != null && _springBootNgrokUrl!.isNotEmpty) {
          print('[URL_CONFIG] 🌐 Using ngrok for Spring Boot: $_springBootNgrokUrl');
          return _springBootNgrokUrl!;
        } else {
          print('[URL_CONFIG] ⚠️ WARNING: ngrok URL not configured, falling back to localhost');
          return 'http://localhost:$_springBootLocalPort';
        }
      }
    }

    // 2️⃣ Android
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_springBootLocalPort';
    }

    // 3️⃣ iOS / Desktop
    return 'http://localhost:$_springBootLocalPort';
  }

  /// Spring Boot WebSocket URL (ws:// 또는 wss://)
  ///
  /// 환경별 자동 선택:
  /// - localhost: ws://localhost:8080/ws/match
  /// - ngrok/배포: wss://...ngrok-free.dev/ws/match
  static String get springBootWebSocketUrl {
    final base = springBootBaseUrl;

    if (base.startsWith('https://')) {
      // HTTPS → WSS
      final wsUrl = base.replaceFirst('https://', 'wss://') + '/ws/match';
      print('[URL_CONFIG] 🔌 WebSocket URL: $wsUrl');
      return wsUrl;
    } else {
      // HTTP → WS
      final wsUrl = base.replaceFirst('http://', 'ws://') + '/ws/match';
      print('[URL_CONFIG] 🔌 WebSocket URL: $wsUrl');
      return wsUrl;
    }
  }

  // ============================================================================
  // 🔹 FastAPI URL 자동 선택
  // ============================================================================

  /// FastAPI HTTP base URL
  ///
  /// 환경별 자동 선택:
  /// - localhost: http://127.0.0.1:8000
  /// - Android: http://10.0.2.2:8000
  /// - ngrok/배포: https://...ngrok-free.dev
  static String get fastApiBaseUrl {
    // 1️⃣ Web 환경
    if (kIsWeb) {
      if (_isLocalhost) {
        // localhost 환경
        print('[URL_CONFIG] 🏠 Using localhost for FastAPI: http://127.0.0.1:$_fastApiLocalPort');
        return 'http://127.0.0.1:$_fastApiLocalPort';
      } else {
        // ngrok/배포 환경
        if (_fastApiNgrokUrl != null && _fastApiNgrokUrl!.isNotEmpty) {
          print('[URL_CONFIG] 🌐 Using ngrok for FastAPI: $_fastApiNgrokUrl');
          return _fastApiNgrokUrl!;
        } else {
          print('[URL_CONFIG] ⚠️ WARNING: FastAPI ngrok URL not configured, falling back to localhost');
          return 'http://127.0.0.1:$_fastApiLocalPort';
        }
      }
    }

    // 2️⃣ Android
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_fastApiLocalPort';
    }

    // 3️⃣ iOS / Desktop
    return 'http://localhost:$_fastApiLocalPort';
  }

  // ============================================================================
  // 🔹 헬퍼 메서드
  // ============================================================================

  /// Spring Boot API 엔드포인트 URL 생성
  static String springBootEndpoint(String path) {
    // path가 /로 시작하지 않으면 추가
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$springBootBaseUrl$normalizedPath';
  }

  /// FastAPI 엔드포인트 URL 생성
  static String fastApiEndpoint(String path) {
    // path가 /로 시작하지 않으면 추가
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$fastApiBaseUrl$normalizedPath';
  }
}
