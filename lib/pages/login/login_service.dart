// login_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginService {
  static const String loginUrl =
      "https://semiconical-shela-loftily.ngrok-free.dev/api/v1/auth/login";
  static const String kakaoUrl =
      "https://semiconical-shela-loftily.ngrok-free.dev/api/v1/auth/kakao";

  // 토큰 저장
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setInt(
      'token_expiry',
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  }

  // 유저 정보 저장
  static Future<void> saveUserInfo({
    required String id,
    required String name,
    required String nickname,
    required String rank,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', id);
    await prefs.setString('user_name', name);
    await prefs.setString('user_nickname', nickname);
    await prefs.setString('user_rank', rank);
  }

  // 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return false;

    final expiry = prefs.getInt('token_expiry') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expiry) return false;

    return true;
  }

  // SharedPreferences에서 유저 닉네임 가져오기
  static Future<String> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_nickname') ?? '';
  }

  // ID/비밀번호 로그인
  static Future<Map<String, dynamic>?> loginWithId(String id, String pw) async {
    final response = await http.post(
      Uri.parse(loginUrl),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({"loginId": id, "loginPw": pw}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      throw Exception("존재하지 않는 사용자입니다.");
    } else {
      throw Exception("로그인 실패: ${response.statusCode}");
    }
  }

  // 카카오 로그인
  static Future<Map<String, dynamic>?> loginWithKakao(
      String kakaoId, String kakaoName) async {
    final response = await http.post(
      Uri.parse(kakaoUrl),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({"loginId": kakaoId, "name": kakaoName}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("카카오 로그인 실패: ${response.statusCode}");
    }
  }
}
