// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 스프링 서버 주소 (내 로컬 IP/포트로 교체)
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8080';

  /// 공통 GET 요청 (타임아웃/에러 처리)
  static Future<http.Response> _get(Uri uri) async {
    try {
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      return res;
    } on SocketException {
      throw Exception('네트워크 연결을 확인하세요.');
    } on HttpException {
      throw Exception('HTTP 통신 오류가 발생했습니다.');
    } on FormatException {
      throw Exception('서버 응답을 해석할 수 없습니다.');
    }
  }

  /// 공통 POST 요청 (타임아웃/에러 처리)
  static Future<http.Response> _post(Uri uri, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return res;
    } on SocketException {
      throw Exception('네트워크 연결을 확인하세요.');
    } on HttpException {
      throw Exception('HTTP 통신 오류가 발생했습니다.');
    } on FormatException {
      throw Exception('서버 응답을 해석할 수 없습니다.');
    }
  }

  /// 유저 전체 조회
  /// GET /hi_light/user/getuser  →  [ {id, name, nickname}, ... ]
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

  /// 유저 추가
  /// POST /hi_light/user/add  {id, name, nickname}
  /// 성공 시 true 반환
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

    if (res.statusCode == 200 || res.statusCode == 201) {
      return true;
    }
    // 서버에서 메시지 내려주면 그대로 노출
    throw Exception('사용자 추가 실패: ${res.statusCode} - ${res.body}');
  }
}

/// 서버 User 응답과 매핑되는 간단 DTO
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
