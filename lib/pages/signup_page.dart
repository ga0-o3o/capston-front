import 'package:flutter/material.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();

    // 간단한 유효성 검사 및 임시 회원가입 처리
    await Future.delayed(const Duration(seconds: 1)); // 네트워크 대기 시뮬레이션

    if (email.isNotEmpty && password.length >= 6 && displayName.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('회원가입 완료'),
              content: const Text('회원가입이 성공적으로 완료되었습니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
      );
    } else {
      setState(() {
        _errorMessage = '모든 필드를 올바르게 입력해주세요.\n(비밀번호는 6자 이상)';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
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
              // 상단 GIF 이미지
              Center(
                child: Image.asset(
                  'assets/images/Saving_Cat1.gif',
                  width: 320,
                  height: 320,
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
                          // 이름
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: '이름',
                              filled: true,
                              fillColor: Colors.white,
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFF4E6E99),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              floatingLabelStyle: TextStyle(
                                color: const Color(0xFF4E6E99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 이메일
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: '이메일',
                              filled: true,
                              fillColor: Colors.white,
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFF4E6E99),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              floatingLabelStyle: TextStyle(
                                color: const Color(0xFF4E6E99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 아이디
                          TextField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: '아이디',
                              filled: true,
                              fillColor: Colors.white,
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFF4E6E99),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              floatingLabelStyle: TextStyle(
                                color: const Color(0xFF4E6E99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 비밀번호
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: '비밀번호',
                              filled: true,
                              fillColor: Colors.white,
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFF4E6E99),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              floatingLabelStyle: TextStyle(
                                color: const Color(0xFF4E6E99),
                              ),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 20),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Center(
                                child: ElevatedButton(
                                  onPressed: _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4E6E99),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(250, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('회원가입'),
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
                                minimumSize: const Size(120, 45), // 가로 폭 줄임
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('뒤로 가기'),
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
