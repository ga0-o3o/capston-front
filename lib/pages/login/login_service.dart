import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginService {
  static const String baseUrl = "http://localhost:8080/api/v1/auth";

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setInt(
      'token_expiry',
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  }

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

  static Future<Map<String, dynamic>?> loginWithId(String id, String pw) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"loginId": id, "loginPw": pw}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("로그인 실패: ${response.statusCode}");
    }
  }

  static Future<Map<String, dynamic>?> loginWithKakao(
      String kakaoId, String kakaoName) async {
    final response = await http.post(
      Uri.parse("$baseUrl/kakao"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"loginId": kakaoId, "name": kakaoName}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("카카오 로그인 실패: ${response.statusCode}");
    }
  }
}
