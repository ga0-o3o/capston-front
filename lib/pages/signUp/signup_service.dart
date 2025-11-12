import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SignupService {
  static const String signupUrl =
      "https://semiconical-shela-loftily.ngrok-free.dev/api/v1/auth/signup";

  // 회원가입 요청
  static Future<void> signup({
    required String id,
    required String pw,
    required String name,
  }) async {
    final response = await http.post(
      Uri.parse(signupUrl),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({"loginId": id, "loginPw": pw, "name": name}),
    );

    if (response.statusCode == 200) {
      // 회원가입 성공
      final data = jsonDecode(response.body);
      // 필요 시 token이나 정보 저장 가능
      final prefs = await SharedPreferences.getInstance();
      if (data['token'] != null) {
        await prefs.setString('jwt_token', data['token']);
      }
      if (data['nickname'] != null) {
        await prefs.setString('user_nickname', data['nickname']);
      }
    } else if (response.statusCode == 400) {
      throw Exception("이미 사용자가 있는 ID입니다.");
    } else {
      throw Exception(
          "회원가입 실패: ${response.statusCode} ${response.reasonPhrase}");
    }
  }
}
