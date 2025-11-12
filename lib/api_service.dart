// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 🌐 API 통신 서비스
class ApiService {
  // 🔹 Spring 서버 주소 (예: 로그인용)
  static const String baseUrl =
      'https://semiconical-shela-loftily.ngrok-free.dev';

  // 🔹 FastAPI 서버 주소
  static String get aiBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    if (Platform.isIOS) return 'http://localhost:8000';
    return 'http://localhost:8000';
  }

  // -----------------------------------------------------------
  // ✅ 공통 함수
  // -----------------------------------------------------------

  static Future<String?> _getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Map<String, String> _headersWithAuth(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> _get(Uri uri, {bool useAuth = false}) async {
    try {
      final token = useAuth ? await _getJwtToken() : null;
      final res = await http
          .get(uri, headers: _headersWithAuth(token))
          .timeout(const Duration(minutes: 5));
      return res;
    } on SocketException {
      throw Exception('네트워크 연결을 확인하세요.');
    } on HttpException {
      throw Exception('HTTP 통신 오류가 발생했습니다.');
    } on FormatException {
      throw Exception('서버 응답을 해석할 수 없습니다.');
    }
  }

  static Future<http.Response> _post(Uri uri, Map<String, dynamic> body,
      {bool useAuth = false}) async {
    try {
      final token = useAuth ? await _getJwtToken() : null;
      final res = await http
          .post(
            uri,
            headers: _headersWithAuth(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 5));
      return res;
    } on SocketException {
      throw Exception('네트워크 연결을 확인하세요.');
    } on HttpException {
      throw Exception('HTTP 통신 오류가 발생했습니다.');
    } on FormatException {
      throw Exception('서버 응답을 해석할 수 없습니다.');
    }
  }

  // -----------------------------------------------------------
  // 🧍 Spring 서버 관련 (회원 기능)
  // -----------------------------------------------------------

  static Future<List<UserDto>> getAllUsers() async {
    final uri = Uri.parse('$baseUrl/hi_light/user/getuser');
    final res = await _get(uri);
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

  static Future<bool> addUser({
    required String id,
    required String name,
    required String nickname,
  }) async {
    final uri = Uri.parse('$baseUrl/hi_light/user/add');
    final res = await _post(uri, {
      'id': id,
      'name': name,
      'nickname': nickname,
    });
    if (res.statusCode == 200 || res.statusCode == 201) return true;
    throw Exception('사용자 추가 실패: ${res.statusCode} - ${res.body}');
  }

  static Future<bool> saveKakaoUser({
    required String id,
    required String name,
  }) async {
    final uri = Uri.parse('$baseUrl/user/save');
    final res = await _post(uri, {
      'id': 'KAKAO$id',
      'name': name,
    });
    if (res.statusCode == 200) return true;
    throw Exception('카카오 사용자 저장 실패: ${res.statusCode} - ${res.body}');
  }

  // -----------------------------------------------------------
  // 🤖 FastAPI 서버 관련 (AI 채팅 / 팟캐스트)
  // -----------------------------------------------------------

  /// 일반 대화 메시지 전송
  /// POST /chat  { message, initialChat }  (JWT 필수)
  static Future<ChatResponse> sendChatMessage({
    required String message,
    bool initialChat = false,
  }) async {
    final uri = Uri.parse('$aiBaseUrl/api/chat'); // ✅ 수정: /chat → /api/chat

    final res = await _post(
        uri,
        {
          'message': message,
          'initialChat': initialChat,
        },
        useAuth: true);

    if (res.statusCode != 200) {
      throw Exception('채팅 전송 실패: ${res.statusCode} - ${res.body}');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return ChatResponse.fromJson(decoded);
  }

  /// 팟캐스트 생성 (선택 기능)
  static Future<PodcastResponse> generatePodcastFromConversation({
    required String conversationHistory,
  }) async {
    final uri = Uri.parse('$aiBaseUrl/api/podcast/generate');
    final res = await _post(
        uri,
        {
          'conversationHistory': conversationHistory,
        },
        useAuth: true);

    if (res.statusCode != 200) {
      throw Exception('팟캐스트 생성 실패: ${res.statusCode} - ${res.body}');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return PodcastResponse.fromJson(decoded);
  }
}

// -----------------------------------------------------------
// 🧱 데이터 클래스들
// -----------------------------------------------------------

class UserDto {
  final String id;
  final String name;
  final String nickname;

  UserDto({required this.id, required this.name, required this.nickname});

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
