import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_user.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import 'mainMenuPage.dart';
import 'levelTest_Page.dart';
import 'loading_page.dart';
import 'dart:html' as html;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// -------------------- 버튼 소리 --------------------
class SoundEffect {
  static void playButton() {
    final audio = html.AudioElement('assets/audios/button_click.mp3');
    audio.play();
  }
}

// -------------------- 애니메이션 버튼 --------------------
class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double fontSize;
  final Widget? icon;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.fontSize = 16,
    this.icon,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    SoundEffect.playButton(); // 딸칵 소리
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onPressed();
  }

  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        width: 250,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black26,
                    offset: const Offset(0, 4),
                    blurRadius: 4,
                  ),
                ],
        ),
        transform: _isPressed
            ? Matrix4.translationValues(0, 3, 0)
            : Matrix4.identity(),
        child: widget.icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  widget.icon!,
                  const SizedBox(width: 8),
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.foregroundColor,
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Text(
                widget.text,
                style: TextStyle(
                  color: widget.foregroundColor,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

// -------------------- LoginPage State --------------------
class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _idFocus = FocusNode();
  final FocusNode _pwFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedToken();
  }

  Future<void> _checkSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final expiry = prefs.getInt('token_expiry');

    if (token != null && expiry != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < expiry) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainMenuPage(userName: '사용자')),
        );
      }
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setInt(
      'token_expiry',
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  }

  Future<void> _saveRank(String rank) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_rank', rank);
  }

  Future<void> _saveNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_nickname', nickname);
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  Future<void> _saveID(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', id);
  }

  Future<void> _loginWithId() async {
    final id = _idController.text.trim();
    final pw = _passwordController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      setState(() => _errorMessage = "아이디와 비밀번호를 입력해주세요.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoadingPage()),
    );

    try {
      final response = await http.post(
        Uri.parse("http://localhost:8080/api/v1/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"loginId": id, "loginPw": pw}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['token'];
        final name = data['name'];
        final nickname = data['nickname'];
        final rank = data['userRank'] ?? 'Beginner';
        final id = data['loginId'];

        await _saveToken(token);
        await _saveID(id);
        await _saveRank(rank);
        await _saveName(name);
        await _saveNickname(nickname);

        Navigator.pop(context);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainMenuPage(userName: nickname)),
        );

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("환영합니다, $nickname 님!")));
      } else {
        Navigator.pop(context);
        setState(() => _errorMessage = "로그인 실패: 서버 오류(${response.statusCode})");
      }
    } catch (e) {
      Navigator.pop(context);
      setState(() => _errorMessage = "네트워크 오류: $e");
    }
  }

  Future<void> _loginWithKakao() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoadingPage()),
    );

    try {
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token;

      if (isInstalled) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      User kakaoUser = await UserApi.instance.me();
      final kakaoId = kakaoUser.id.toString();
      final kakaoName = kakaoUser.kakaoAccount?.profile?.nickname ?? "사용자";

      final response = await http.post(
        Uri.parse("http://localhost:8080/api/v1/auth/kakao"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"loginId": kakaoId, "name": kakaoName}),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['token'];
        final name = data['name'];
        final nickname = data['nickname'];
        final rank = data['userRank'] ?? 'Beginner';
        final id = data['loginId'];

        await _saveToken(token);
        await _saveID(id);
        await _saveRank(rank);
        await _saveName(name);
        await _saveNickname(nickname);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("환영합니다, $nickname 님!")));

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MainMenuPage(userName: name)),
          );
        });
      } else {
        setState(
            () => _errorMessage = "카카오 로그인 후 서버 저장 실패: ${response.statusCode}");
      }
    } catch (error) {
      Navigator.pop(context);
      setState(() {
        _errorMessage = '카카오 로그인 실패: $error';
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _idFocus.dispose();
    _pwFocus.dispose();
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
            focusNode: _idFocus,
            decoration: _inputDecoration('아이디', Icons.person),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              FocusScope.of(context).requestFocus(_pwFocus);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            focusNode: _pwFocus,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '비밀번호',
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF4E6E99)),
              filled: true,
              fillColor: const Color(0xFFF0EDEE),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFBDA68B)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide:
                    const BorderSide(color: Color(0xFF4E6E99), width: 2),
              ),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4E6E99)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF4E6E99),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loginWithId(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          AnimatedButton(
            text: '로그인',
            backgroundColor: const Color(0xFF4E6E99),
            foregroundColor: Colors.white,
            fontSize: 18,
            onPressed: _loginWithId,
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
          padding: const EdgeInsets.symmetric(horizontal: 150),
          child: AnimatedButton(
            text: '카카오톡 로그인',
            icon: SizedBox(
              height: 24,
              width: 24,
              child: Image.asset('assets/images/kakao_logo.png'),
            ),
            backgroundColor: const Color(0xFFFFE812),
            foregroundColor: Colors.black,
            fontSize: 18,
            onPressed: _loginWithKakao,
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
