// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ✅ 중앙 URL 관리 import
import 'config/url_config.dart';

/// 🌐 API 통신 서비스
///
/// 역할 구분:
/// - baseUrl (Spring Boot): 로그인, 인증, 유저 관리
/// - fastApiUrl (FastAPI): AI 챗봇, 레벨 테스트, OCR
///
/// ⚠️ 중요: Spring Boot와 FastAPI는 **다른 서버**입니다!
///          채팅 API는 반드시 fastApiUrl로 전송되어야 합니다.
class ApiService {
  // ============================================================================
  // 🔹 서버 주소 설정 (중앙 관리)
  // ============================================================================

  // ============================================================================
  // Spring Boot 서버 (로그인, 인증, 유저 관리)
  // ============================================================================
  /// ✅ Spring Boot URL은 UrlConfig에서 자동으로 가져옵니다
  static String get baseUrl => UrlConfig.springBootBaseUrl;

  // ============================================================================
  // FastAPI 서버 (AI 챗봇, 레벨 테스트, OCR)
  // ============================================================================
  //
  // ⚠️ 중요: FastAPI는 Spring Boot와 **다른 서버**입니다!
  //
  // ✅ FastAPI URL은 UrlConfig에서 자동으로 관리됩니다:
  //    - localhost 환경: http://127.0.0.1:8000
  //    - ngrok/배포 환경: config/url_config.dart에서 설정한 ngrok URL
  //
  // ============================================================================

  /// FastAPI URL 반환 (UrlConfig에서 자동으로 가져옴)
  ///
  /// 환경별 URL 자동 선택:
  /// - Web (localhost): http://127.0.0.1:8000
  /// - Web (ngrok): ngrok URL
  /// - Android: http://10.0.2.2:8000 (에뮬레이터)
  /// - iOS: http://localhost:8000 (시뮬레이터)
  static String get fastApiUrl => UrlConfig.fastApiBaseUrl;

  // ============================================================================
  // 🔹 JWT 토큰 관리
  // ============================================================================

  /// JWT 토큰 미리 로드 및 검증
  ///
  /// ⚠️ Web 환경에서 SharedPreferences는 IndexedDB를 사용하여 느릴 수 있습니다.
  ///    API 호출 전에 이 함수를 먼저 호출하여 토큰을 미리 로드하세요!
  static Future<bool> ensureTokenLoaded() async {
    try {
      print('[API_SERVICE] 🔄 Ensuring token is loaded...');
      final prefs = await SharedPreferences.getInstance();

      // SharedPreferences 강제 reload (Web 환경 대응)
      await Future.delayed(const Duration(milliseconds: 100));

      final token = prefs.getString('jwt_token');
      final expiry = prefs.getInt('token_expiry') ?? 0;

      if (token == null || token.isEmpty) {
        print('[API_SERVICE] ❌ No token found');
        print('[API_SERVICE] Available keys: ${prefs.getKeys().toList()}');
        return false;
      }

      if (DateTime.now().millisecondsSinceEpoch > expiry) {
        print('[API_SERVICE] ❌ Token expired');
        return false;
      }

      print('[API_SERVICE] ✅ Token loaded successfully');
      return true;
    } catch (e) {
      print('[API_SERVICE] ❌ Error loading token: $e');
      return false;
    }
  }

  /// JWT 토큰 가져오기 (재시도 로직 포함)
  ///
  /// Web 환경에서 SharedPreferences 로딩이 느릴 수 있으므로 재시도 로직 추가
  static Future<String?> _getJwtToken({int retries = 3}) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // 첫 시도가 아니면 약간 대기 (Web 환경 대응)
        if (attempt > 1) {
          print('[API_SERVICE] 🔄 Retry attempt $attempt/$retries...');
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        }

        final token = prefs.getString('jwt_token');

        if (token == null || token.isEmpty) {
          if (attempt < retries) {
            print('[API_SERVICE] ⚠️ No token found, retrying...');
            continue;
          }
          print('[API_SERVICE] ❌ No JWT token found after $retries attempts');
          print('[API_SERVICE] All SharedPreferences keys: ${prefs.getKeys().toList()}');
          return null;
        }

        // 토큰 만료 확인
        final expiry = prefs.getInt('token_expiry') ?? 0;
        if (DateTime.now().millisecondsSinceEpoch > expiry) {
          print('[API_SERVICE] ⚠️ Warning: JWT token expired');
          return null;
        }

        print('[API_SERVICE] ✅ JWT token found (attempt $attempt): ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
        return token;
      } catch (e) {
        print('[API_SERVICE] ❌ Error getting token (attempt $attempt): $e');
        if (attempt >= retries) rethrow;
      }
    }

    return null;
  }

  // ============================================================================
  // 🔹 공통 헤더 생성
  // ============================================================================

  /// 인증 헤더 포함한 공통 헤더 생성
  ///
  /// [token]: JWT 토큰 (null이면 Authorization 헤더 제외)
  static Map<String, String> _buildHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',

      // ✅ ngrok 브라우저 경고 우회 헤더 (모든 요청에 포함)
      'ngrok-skip-browser-warning': '69420',
      'Ngrok-Skip-Browser-Warning': '69420',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };

    // ✅ Authorization 헤더 (토큰이 있을 경우)
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      print('[API_SERVICE] ✅ Authorization header added');
    } else {
      print('[API_SERVICE] ⚠️ No Authorization header (token not provided)');
    }

    return headers;
  }

  // ============================================================================
  // 🔹 HTTP 요청 공통 함수
  // ============================================================================

  /// GET 요청
  static Future<http.Response> _get(
    Uri uri, {
    bool useAuth = false,
  }) async {
    try {
      final token = useAuth ? await _getJwtToken() : null;

      print('');
      print('╔════════════════════════════════════════════════════════════');
      print('║ [API_SERVICE] 📡 GET Request');
      print('╠════════════════════════════════════════════════════════════');
      print('║ URL: ${uri.toString()}');
      print('║ useAuth: $useAuth');
      print('║ hasToken: ${token != null}');
      print('╚════════════════════════════════════════════════════════════');

      final res = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(const Duration(minutes: 5));

      print('[API_SERVICE] Response status: ${res.statusCode}');
      return res;
    } on SocketException {
      throw Exception('네트워크 연결을 확인하세요.');
    } on HttpException {
      throw Exception('HTTP 통신 오류가 발생했습니다.');
    } on FormatException {
      throw Exception('서버 응답을 해석할 수 없습니다.');
    } on TimeoutException {
      throw Exception('서버 응답 시간이 초과되었습니다 (5분).');
    }
  }

  /// POST 요청
  static Future<http.Response> _post(
    Uri uri,
    Map<String, dynamic> body, {
    bool useAuth = false,
  }) async {
    try {
      final token = useAuth ? await _getJwtToken() : null;

      // ✅ 인증 필요한데 토큰 없으면 명확한 에러
      if (useAuth && (token == null || token.isEmpty)) {
        print('[API_SERVICE] ❌ ERROR: Authentication required but no token found!');
        throw Exception('No auth token found. Please login first.');
      }

      print('');
      print('╔════════════════════════════════════════════════════════════');
      print('║ [API_SERVICE] 📡 POST Request');
      print('╠════════════════════════════════════════════════════════════');
      print('║ URL: ${uri.toString()}');
      print('║ useAuth: $useAuth');
      print('║ hasToken: ${token != null}');
      print('║ Body keys: ${body.keys.toList()}');
      print('╚════════════════════════════════════════════════════════════');

      final res = await http
          .post(
            uri,
            headers: _buildHeaders(token: token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 5));

      print('[API_SERVICE] Response status: ${res.statusCode}');

      // ✅ 401 Unauthorized 처리
      if (res.statusCode == 401) {
        print('[API_SERVICE] ❌ 401 Unauthorized - Token may be invalid or expired');
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      }

      return res;
    } on SocketException {
      throw Exception('네트워크 연결을 확인하세요.');
    } on HttpException {
      throw Exception('HTTP 통신 오류가 발생했습니다.');
    } on FormatException {
      throw Exception('서버 응답을 해석할 수 없습니다.');
    } on TimeoutException {
      throw Exception('서버 응답 시간이 초과되었습니다 (5분).');
    }
  }

  // ============================================================================
  // 🧍 Spring Boot 서버 API (회원 관리)
  // ============================================================================

  /// 모든 사용자 조회
  static Future<List<UserDto>> getAllUsers() async {
    print('[API_SERVICE] 🧍 Fetching all users from Spring Boot');
    final uri = Uri.parse('$baseUrl/hi_light/user/getuser');
    final res = await _get(uri, useAuth: false);

    if (res.statusCode != 200) {
      throw Exception('사용자 조회 실패: ${res.statusCode} - ${res.body}');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) {
      throw Exception('예상과 다른 응답 형식입니다: ${res.body}');
    }

    return decoded
        .map<UserDto>((e) => UserDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 사용자 추가
  static Future<bool> addUser({
    required String id,
    required String name,
    required String nickname,
  }) async {
    print('[API_SERVICE] 🧍 Adding user to Spring Boot');
    final uri = Uri.parse('$baseUrl/hi_light/user/add');
    final res = await _post(uri, {
      'id': id,
      'name': name,
      'nickname': nickname,
    }, useAuth: false);

    if (res.statusCode == 200 || res.statusCode == 201) return true;
    throw Exception('사용자 추가 실패: ${res.statusCode} - ${res.body}');
  }

  /// 카카오 사용자 저장
  static Future<bool> saveKakaoUser({
    required String id,
    required String name,
  }) async {
    print('[API_SERVICE] 🧍 Saving Kakao user to Spring Boot');
    final uri = Uri.parse('$baseUrl/user/save');
    final res = await _post(uri, {
      'id': 'KAKAO$id',
      'name': name,
    }, useAuth: false);

    if (res.statusCode == 200) return true;
    throw Exception('카카오 사용자 저장 실패: ${res.statusCode} - ${res.body}');
  }

  // ============================================================================
  // 🤖 FastAPI 서버 API (AI 챗봇 / 팟캐스트)
  // ============================================================================

  /// 일반 대화 메시지 전송
  ///
  /// ⚠️ 중요: 이 API는 **FastAPI 서버**로 전송됩니다!
  ///         Spring Boot가 아닌 fastApiUrl을 사용합니다.
  ///
  /// POST /api/chat
  /// Request: { message, initialChat }
  /// Response: { response, audio, chatNum, chatOrder }
  ///
  /// [message]: 사용자 메시지
  /// [initialChat]: 첫 대화 여부 (기본값: false)
  static Future<ChatResponse> sendChatMessage({
    required String message,
    bool initialChat = false,
  }) async {
    // ✅ FastAPI URL 사용 (Spring Boot 아님!)
    final url = fastApiUrl;  // 먼저 URL을 가져와서 로깅
    final uri = Uri.parse('$url/api/chat');

    print('');
    print('╔════════════════════════════════════════════════════════════');
    print('║ [API_SERVICE] 🤖 Sending chat message to FastAPI');
    print('╠════════════════════════════════════════════════════════════');
    print('║ FastAPI URL: $url');
    print('║ Full endpoint: ${uri.toString()}');
    print('║ ⚠️ Verify this is NOT Spring Boot URL!');
    print('║ Spring Boot URL: $baseUrl');
    print('║ Are they different? ${url != baseUrl ? "✅ YES" : "❌ NO (ERROR!)"}');
    print('╚════════════════════════════════════════════════════════════');

    if (url == baseUrl) {
      print('');
      print('╔════════════════════════════════════════════════════════════');
      print('║ [API_SERVICE] ⚠️ WARNING!');
      print('╠════════════════════════════════════════════════════════════');
      print('║ FastAPI URL is same as Spring Boot URL!');
      print('║ This may cause 401 or 404 errors.');
      print('║');
      print('║ FastAPI URL: $url');
      print('║ Spring Boot URL: $baseUrl');
      print('╚════════════════════════════════════════════════════════════');
      print('');
    }

    final res = await _post(
      uri,
      {
        'message': message,
        'initialChat': initialChat,
      },
      useAuth: true,  // ✅ JWT 토큰 필수
    );

    if (res.statusCode != 200) {
      print('[API_SERVICE] ❌ Chat API failed: ${res.statusCode}');
      print('[API_SERVICE] Response body: ${res.body}');
      throw Exception('채팅 전송 실패: ${res.statusCode} - ${res.body}');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return ChatResponse.fromJson(decoded);
  }

  /// 팟캐스트 생성
  ///
  /// ⚠️ 중요: 이 API는 **FastAPI 서버**로 전송됩니다!
  ///
  /// POST /api/podcast/generate
  /// Request: { conversationHistory }
  /// Response: { topic, script, audio }
  static Future<PodcastResponse> generatePodcastFromConversation({
    required String conversationHistory,
  }) async {
    // ✅ FastAPI URL 사용 (Spring Boot 아님!)
    final url = fastApiUrl;
    final uri = Uri.parse('$url/api/podcast/generate');

    print('[API_SERVICE] 🎙️ Generating podcast from conversation (FastAPI)');
    print('[API_SERVICE] FastAPI URL: $url');

    final res = await _post(
      uri,
      {
        'conversationHistory': conversationHistory,
      },
      useAuth: true,  // ✅ JWT 토큰 필수
    );

    if (res.statusCode != 200) {
      throw Exception('팟캐스트 생성 실패: ${res.statusCode} - ${res.body}');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return PodcastResponse.fromJson(decoded);
  }
}

// ============================================================================
// 🧱 데이터 클래스들
// ============================================================================

class UserDto {
  final String id;
  final String name;
  final String nickname;

  UserDto({
    required this.id,
    required this.name,
    required this.nickname,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
      );
}

class ChatResponse {
  final String text;
  final String? audioBase64;
  final int chatNum;
  final int chatOrder;

  ChatResponse({
    required this.text,
    this.audioBase64,
    required this.chatNum,
    required this.chatOrder,
  });

  bool get isPodcast => audioBase64 != null && audioBase64!.isNotEmpty;

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      text: json['response'] ?? 'No response',
      audioBase64: json['audio'],
      chatNum: json['chatNum'] ?? 0,
      chatOrder: json['chatOrder'] ?? 0,
    );
  }
}

class PodcastResponse {
  final String topic;
  final String script;
  final String audioBase64;

  PodcastResponse({
    required this.topic,
    required this.script,
    required this.audioBase64,
  });

  factory PodcastResponse.fromJson(Map<String, dynamic> json) {
    return PodcastResponse(
      topic: json['topic'] ?? '',
      script: json['script'] ?? '',
      audioBase64: json['audio'] ?? '',
    );
  }
}
