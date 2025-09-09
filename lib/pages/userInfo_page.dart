import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({Key? key}) : super(key: key);

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  String userId = '';
  String userName = '';
  String nickname = '';
  String userRank = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // SharedPreferences에서 사용자 정보 불러오기
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id') ?? '알 수 없음';
      userName = prefs.getString('user_name') ?? '사용자';
      nickname = prefs.getString('user_nickname') ?? '닉네임 없음';
      userRank = prefs.getString('user_rank') ?? 'Beginner';
    });
  }

  // 닉네임 변경
  Future<void> _changeNickname() async {
    final TextEditingController _controller = TextEditingController(
      text: nickname,
    );

    final newNickname = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('닉네임 변경'),
            content: TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: '새 닉네임'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(context, _controller.text.trim()),
                child: const Text('변경'),
              ),
            ],
          ),
    );

    if (newNickname == null || newNickname.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getString('user_id') ?? "";

    if (token == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    final uri = Uri.parse("http://localhost:8080/api/user/nickname");

    try {
      final response = await http.put(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // 로그인 시 받은 토큰 사용
        },
        body: jsonEncode({"id": userId, "nickname": newNickname}),
      );

      print('PUT 요청 상태 코드: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          nickname = data['nickname']; // 서버에서 내려온 닉네임 갱신
        });
        await prefs.setString('user_nickname', nickname);

        print("✅ 닉네임 업데이트 성공: $nickname");
      } else if (response.statusCode == 403) {
        print("❌ 권한 거부 403 - 서버에서 JWT 검증 실패 가능");
      } else {
        print("❌ PUT 요청 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ 닉네임 업데이트 중 오류: $e");
    }
  }

  // 로그아웃
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 정보'),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              userName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('닉네임: $nickname', style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _changeNickname,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '랭크: $userRank',
              style: const TextStyle(fontSize: 18, color: Colors.deepPurple),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '로그아웃',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
