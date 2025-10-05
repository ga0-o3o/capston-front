// login_form.dart
import 'package:flutter/material.dart';
import 'login_service.dart';
import '../mainMenuPage.dart';
import '../loading_page.dart';
import 'animated_button.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _idFocus = FocusNode();
  final _pwFocus = FocusNode();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await LoginService.isLoggedIn();
    if (loggedIn && mounted) {
      final nickname = await LoginService.getNickname();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainMenuPage(userName: nickname)),
      );
    }
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

  Future<void> _login() async {
    final id = _idController.text.trim();
    final pw = _pwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      setState(() => _errorMessage = "아이디와 비밀번호를 입력해주세요.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoadingPage()),
    );

    try {
      final data = await LoginService.loginWithId(id, pw);

      // 서버에서 받은 데이터 저장
      await LoginService.saveToken(data!['token']);
      await LoginService.saveUserInfo(
        id: data['loginId'],
        name: data['name'],
        nickname: data['nickname'],
        rank: data['userRank'] ?? 'Beginner',
      );

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainMenuPage(userName: data['nickname']),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 아이디 입력
          SizedBox(
            width: 450,
            child: TextField(
              controller: _idController,
              focusNode: _idFocus,
              decoration: _inputDecoration('아이디', Icons.person),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).requestFocus(_pwFocus),
            ),
          ),
          const SizedBox(height: 12),

          // 비밀번호 입력
          SizedBox(
            width: 450,
            child: TextField(
              controller: _pwController,
              focusNode: _pwFocus,
              obscureText: _obscurePassword,
              decoration: _inputDecoration('비밀번호', Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF4E6E99),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),

          // 로그인 버튼
          AnimatedButton(
            text: '로그인',
            backgroundColor: const Color(0xFF4E6E99),
            foregroundColor: Colors.white,
            fontSize: 18,
            onPressed: _login,
          ),
        ],
      ),
    );
  }
}
