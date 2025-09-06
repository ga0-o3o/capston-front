import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';

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
      final response = await http.post(
        Uri.parse("http://localhost:8080/api/user/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id, "pw": pw, "name": name}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("회원가입 성공"),
                content: const Text("회원가입이 완료되었습니다. 로그인 해주세요."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text("확인"),
                  ),
                ],
              ),
        );
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
                            decoration: const InputDecoration(
                              labelText: "비밀번호",
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: "이름"),
                          ),
                          const SizedBox(height: 20),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Center(
                                child: ElevatedButton(
                                  onPressed: _signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4E6E99),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(250, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text("회원가입"),
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
