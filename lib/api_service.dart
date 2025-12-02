// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
class ApiService {
  // ============================================================================
  // 🔹 서버 주소 설정 (중앙 관리)
  // ============================================================================

  /// Spring Boot 서버 (로그인, 인증, 유저 관리)
  static String get baseUrl => UrlConfig.springBootBaseUrl;

  /// FastAPI 서버 (AI 챗봇, 레벨 테스트, OCR)
  static String get fastApiUrl => UrlConfig.fastApiBaseUrl;

  // ============================================================================
  // 🔹 JWT 토큰 관리
  // ============================================================================

  /// JWT 토큰 미리 로드 및 검증 (선택적)
  static Future<bool> ensureTokenLoaded() async {
    try {
      print('[API_SERVICE] 🔄 Ensuring token is loaded...');
      final prefs = await SharedPreferences.getInstance();

      await Future.delayed(const Duration(milliseconds: 100));

      final token = prefs.getString('jwt_token');
      final expiry = prefs.getInt('token_expiry') ?? 0;

      if (token == null || token.isEmpty) {
        print('[API_SERVICE] ❌ No token found');
        print('[API_SERVICE] Available keys: ${prefs.getKeys().toList()}');
        return false;
      }

      if (expiry > 0 && DateTime.now().millisecondsSinceEpoch > expiry) {
        print(
            '[API_SERVICE] ⚠️ Token may be expired (token_expiry passed), but backend will validate.');
      }

      print(
          '[API_SERVICE] ✅ Token loaded (prefix): ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      return true;
    } catch (e) {
      print('[API_SERVICE] ❌ Error loading token: $e');
      return false;
    }
  }

  /// JWT 토큰 가져오기 (재시도 로직 포함)
  /// ⚠️ 여기서는 token_expiry가 지나도 토큰은 그대로 돌려줍니다.
  ///    진짜 만료 여부는 백엔드에서 판단하도록 합니다.
  static Future<String?> _getJwtToken({int retries = 3}) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();

        if (attempt > 1) {
          print('[API_SERVICE] 🔄 Retry getting token ($attempt/$retries)...');
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        }

        final token = prefs.getString('jwt_token');

        if (token == null || token.isEmpty) {
          if (attempt < retries) {
            print('[API_SERVICE] ⚠️ No token found, retrying...');
            continue;
          }
          print('[API_SERVICE] ❌ No JWT token found after $retries attempts');
          print(
              '[API_SERVICE] All SharedPreferences keys: ${prefs.getKeys().toList()}');
          return null;
        }

        final expiry = prefs.getInt('token_expiry');
        if (expiry != null &&
            expiry > 0 &&
            DateTime.now().millisecondsSinceEpoch > expiry) {
          print(
              '[API_SERVICE] ⚠️ token_expiry passed, but token will be sent to backend. Backend will validate.');
        }

        print(
            '[API_SERVICE] ✅ JWT token acquired (attempt $attempt): ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
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

  static Map<String, String> _buildHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': '69420',
      'Ngrok-Skip-Browser-Warning': '69420',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };

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

      if (useAuth && (token == null || token.isEmpty)) {
        print(
            '[API_SERVICE] ❌ ERROR: Authentication required but no token found!');
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

      if (res.statusCode == 401) {
        print(
            '[API_SERVICE] ❌ 401 Unauthorized - Token may be invalid or expired');
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
    final res = await _post(
      uri,
      {
        'id': id,
        'name': name,
        'nickname': nickname,
      },
      useAuth: false,
    );

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
    final res = await _post(
      uri,
      {
        'id': 'KAKAO$id',
        'name': name,
      },
      useAuth: false,
    );

    if (res.statusCode == 200) return true;
    throw Exception('카카오 사용자 저장 실패: ${res.statusCode} - ${res.body}');
  }

  // ============================================================================
  // 🤖 FastAPI 서버 API (채팅 / 팟캐스트)
  // ============================================================================

  /// 🔹 채팅 로그 가져오기
  /// GET /api/chat/logs
  static Future<List<Map<String, dynamic>>> getChatLogs(
      {int? chatOrder}) async {
    try {
      final url = UrlConfig.fastApiChatPodcastBaseUrl;

      var uri = Uri.parse('$url/api/chat/logs');

      if (chatOrder != null) {
        uri =
            uri.replace(queryParameters: {'chat_order': chatOrder.toString()});
      }

      print('[API_SERVICE] 🔍 Getting chat logs from: $uri');

      final res = await _get(uri, useAuth: true);

      print('[API_SERVICE] Chat logs status: ${res.statusCode}');
      print('[API_SERVICE] Chat logs body: ${res.body}');

      if (res.statusCode == 401) {
        throw Exception('채팅 로그 조회 실패: 인증이 필요합니다 (401).');
      }
      if (res.statusCode != 200) {
        throw Exception('채팅 로그 조회 실패: ${res.statusCode} - ${res.body}');
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));

      final logs = (decoded['logs'] as List<dynamic>)
          .map((log) => log as Map<String, dynamic>)
          .toList();

      print('[API_SERVICE] ✅ Loaded ${logs.length} chat logs');
      return logs;
    } catch (e) {
      print('[API_SERVICE] ❌ Failed to get chat logs: $e');
      rethrow;
    }
  }

  /// 일반 대화 메시지 전송
  /// POST /api/chat
  static Future<ChatResponse> sendChatMessage({
    required String message,
    bool initialChat = false,
  }) async {
    final url = UrlConfig.fastApiChatPodcastBaseUrl;

    final uri = Uri.parse('$url/api/chat');

    print('');
    print('╔════════════════════════════════════════════════════════════');
    print('║ [API_SERVICE] 🤖 Sending chat message to FastAPI');
    print('╠════════════════════════════════════════════════════════════');
    print('║ FastAPI URL: $url');
    print('║ Full endpoint: ${uri.toString()}');
    print('║ Spring Boot URL: $baseUrl');
    print('╚════════════════════════════════════════════════════════════');

    final res = await _post(
      uri,
      {
        'message': message,
        'initialChat': initialChat,
      },
      useAuth: true,
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
  /// POST /api/podcast/generate
  static Future<PodcastResponse> generatePodcastFromConversation({
    required String conversationHistory,
  }) async {
    final url = UrlConfig.fastApiChatPodcastBaseUrl;

    final uri = Uri.parse('$url/api/podcast/generate');

    print('[API_SERVICE] 🎙️ Generating podcast from conversation (FastAPI)');
    print('[API_SERVICE] FastAPI URL: $url');

    final res = await _post(
      uri,
      {
        'conversationHistory': conversationHistory,
      },
      useAuth: true,
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
