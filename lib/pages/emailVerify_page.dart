import 'package:flutter/material.dart';
import 'signup_page.dart';

class EmailVerifyPage extends StatefulWidget {
  const EmailVerifyPage({super.key});

  @override
  State<EmailVerifyPage> createState() => _EmailVerifyPageState();
}

class _EmailVerifyPageState extends State<EmailVerifyPage> {
  final TextEditingController _emailController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _sendVerificationEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains("@")) {
      setState(() => _errorMessage = "올바른 이메일을 입력하세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // TODO: 실제 이메일 인증 API 호출
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 인증 성공 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("인증 완료"),
            content: const Text("이메일 인증이 완료되었습니다. 회원가입 페이지로 이동합니다."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 다이얼로그 닫기
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SignupPage(verifiedEmail: email),
                    ),
                  );
                },
                child: const Text("확인"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 248, 246),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 40),
          child: Column(
            children: [
              // 상단 GIF
              Center(
                child: Image.asset(
                  'assets/images/Verifying_Cat1.gif',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              // 이메일 인증 카드
              Center(
                child: Container(
                  width: 400,
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
                            "이메일 인증",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4E6E99),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            cursorColor: const Color(0xFF4E6E99), // 커서 색상
                            decoration: InputDecoration(
                              labelText: "이메일",
                              labelStyle: const TextStyle(
                                color: Color(0xFF4E6E99),
                              ), // 라벨 기본 색
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color(0xFF4E6E99),
                                  width: 2,
                                ), // 포커스 테두리
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ), // 일반 테두리
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Center(
                                child: ElevatedButton(
                                  onPressed: _sendVerificationEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4E6E99),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(250, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text("인증 메일 보내기"),
                                ),
                              ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
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
