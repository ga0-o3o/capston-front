import 'dart:convert';
import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'emailVerify_page.dart';
import 'mainMenuPage.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_user.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

const String springBaseUrl = 'http://192.168.0.12:8080'; // ← 본인의 스프링 서버 IP:PORT

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginWithEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 여기서 실제 서버 인증 로직 추가 가능
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

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

      setState(() {
        _isLoading = false;
      });

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
    _emailController.dispose();
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
              // 상단 캐릭터 이미지
              Center(
                child: Image.asset(
                  'assets/images/covering_cat1.gif',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const Text(
                'Log in on HiLight :)',
                style: TextStyle(fontSize: 26, color: Colors.black),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Container(
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
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: '이메일',
                          prefixIcon: Icon(
                            Icons.email,
                            color: Color(0xFF4E6E99),
                          ),
                          filled: true,
                          fillColor: Color(0xFFF0EDEE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Color(0xFFBDA68B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: Color(0xFF4E6E99),
                              width: 2,
                            ),
                          ),
                          floatingLabelStyle: TextStyle(
                            color: Color(0xFF4E6E99),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: Icon(
                            Icons.lock,
                            color: Color(0xFF4E6E99),
                          ),
                          filled: true,
                          fillColor: Color(0xFFF0EDEE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Color(0xFFBDA68B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: Color(0xFF4E6E99),
                              width: 2,
                            ),
                          ),
                          floatingLabelStyle: TextStyle(
                            color: Color(0xFF4E6E99),
                          ),
                        ),
                        obscureText: true,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                            width: 200,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loginWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4E6E99),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                '로그인',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                '-- SNS 계정으로 로그인 --',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F3551),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 150),
                child: ElevatedButton.icon(
                  icon: SizedBox(
                    height: 24,
                    width: 24,
                    child: Image.asset('assets/images/kakao_logo.png'),
                  ),
                  label: const Text(
                    '카카오톡 로그인',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _loginWithKakao,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE812),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmailVerifyPage()),
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
          ),
        ),
      ),
    );
  }
}
