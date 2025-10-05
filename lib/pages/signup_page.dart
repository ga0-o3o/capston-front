import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // ✅ 회원가입 함수
  Future<void> _signup() async {
    final id = _idController.text.trim();
    final pw = _pwController.text.trim();
    final name = _nameController.text.trim();

    if (id.isEmpty || pw.isEmpty || name.isEmpty) {
      setState(() => _errorMessage = "모든 필드를 입력해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse("http://localhost:8080/api/v1/auth/signup"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "loginId": id,
          "loginPw": pw,
          "name": name,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: 350,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/dialog1.png',
                    width: 350,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '회원가입 성공',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '회원가입이 완료되었습니다.\n로그인 해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E6E99),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (response.statusCode == 400) {
        setState(() {
          _errorMessage = "이미 사용자가 있는 ID입니다.";
        });
      } else {
        setState(() {
          _errorMessage =
              "회원가입 실패: ${response.statusCode} ${response.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "오류 발생: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 248, 246),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 0),
          child: Column(
            children: [
              // 상단 GIF
              Center(
                child: Image.asset(
                  'assets/images/Saving_Cat1.gif',
                  width: 320,
                  height: 320,
                  gaplessPlayback: true, // ✅ 이 옵션이 중요
                ),
              ),

              // 회원가입 카드
              Center(
                child: Container(
                  width: 500,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "회원가입",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4E6E99),
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextField(
                            controller: _idController,
                            decoration: const InputDecoration(labelText: "아이디"),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pwController,
                            obscureText: true,
                            decoration:
                                const InputDecoration(labelText: "비밀번호"),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: "이름"),
                          ),
                          const SizedBox(height: 20),

                          // ✅ 여기서 딸깍 애니메이션 버튼 사용
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Center(
                                  child: AnimatedButton(
                                    text: "회원가입",
                                    backgroundColor: const Color(0xFF4E6E99),
                                    foregroundColor: Colors.white,
                                    fontSize: 15,
                                    onPressed: _signup,
                                  ),
                                ),

                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),

                          const SizedBox(height: 12),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(120, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("뒤로 가기"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ ✅ 딸깍 애니메이션 버튼 ------------------
class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double fontSize;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.fontSize = 15,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
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
        width: 230,
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(8),
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
            ? Matrix4.translationValues(0, 2, 0)
            : Matrix4.identity(),
        child: Text(
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
