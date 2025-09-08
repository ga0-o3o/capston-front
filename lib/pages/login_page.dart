import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_user.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import 'mainMenuPage.dart';
import 'levelTest_Page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedToken();
  }

  // 이미 로그인된 토큰이 있는지 확인
  Future<void> _checkSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final expiry = prefs.getInt('token_expiry');

    if (token != null && expiry != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < expiry) {
        // 토큰 유효 → 바로 메인 메뉴로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainMenuPage(userName: '사용자')),
        );
      }
    }
  }

  // 토큰 저장 (만료 시간 1시간)
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setInt(
      'token_expiry',
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  }

  // ID + PW 로그인
  Future<void> _loginWithId() async {
    final id = _idController.text.trim();
    final pw = _passwordController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      setState(() => _errorMessage = "아이디와 비밀번호를 입력해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse("http://localhost:8080/api/user/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id, "pw": pw}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final nickname = data['nickname'] ?? id;

        await _saveToken(token);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("환영합니다, $nickname 님!")));

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MainMenuPage(userName: nickname)),
          );
        });
      } else if (response.statusCode == 400) {
        setState(() => _errorMessage = "아이디 또는 비밀번호가 틀립니다.");
      } else {
        setState(() => _errorMessage = "로그인 실패: 서버 오류(${response.statusCode})");
      }
    } catch (e) {
      setState(() => _errorMessage = "네트워크 오류: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 카카오 로그인
  Future<void> _loginWithKakao() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token;

      if (isInstalled) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      User user = await UserApi.instance.me();

      // 여기선 JWT 토큰이 아니라 Kakao 토큰
      await _saveToken(token.accessToken);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '환영합니다, ${user.kakaoAccount?.profile?.nickname ?? "사용자"}님!',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => MainMenuPage(
                userName: user.kakaoAccount?.profile?.nickname ?? '사용자',
              ),
        ),
      );
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = '카카오 로그인 실패: $error';
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 248, 246),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Center(
                child: Image.asset(
                  'assets/images/covering_cat1.gif',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Log in on HiLight :)',
                style: TextStyle(fontSize: 26, color: Colors.black),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: _buildLoginForm(),
              ),
              const SizedBox(height: 20),
              _buildSNSLogin(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _idController,
            decoration: _inputDecoration('아이디', Icons.person),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: _inputDecoration('비밀번호', Icons.lock),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator()
              : SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loginWithId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6E99),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // 둥근 네모
                    ),
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 18, // 글자 크기
                      fontWeight: FontWeight.bold, // 굵게
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4E6E99)),
      filled: true,
      fillColor: const Color(0xFFF0EDEE),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFFBDA68B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFF4E6E99), width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: Color(0xFF4E6E99)),
    );
  }

  Widget _buildSNSLogin() {
    return Column(
      children: [
        const Text(
          '-- SNS 계정으로 로그인 --',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 150), // 버튼 좌우 공간 조절
          child: SizedBox(
            width: 250, // 화면 가로 전체 사용
            height: 40, // 버튼 높이
            child: ElevatedButton.icon(
              icon: SizedBox(
                height: 24, // 로고 크기
                width: 24,
                child: Image.asset('assets/images/kakao_logo.png'),
              ),
              label: const Text(
                '카카오톡 로그인',
                style: TextStyle(fontSize: 18), // 글자 크기
              ),
              onPressed: _loginWithKakao,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFE812),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // 둥근 네모
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupPage()),
            );
          },
          child: const Text(
            '회원가입',
            style: TextStyle(
              color: Color(0xFF1F3551),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
