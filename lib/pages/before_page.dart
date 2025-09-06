import 'package:flutter/material.dart';
import 'login_page.dart';
import 'emailVerify_page.dart';
import 'users_page.dart';

class BeforePage extends StatelessWidget {
  const BeforePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC6CBD2), // 아이보리 배경 색상
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 이미지 배치
            Image.asset(
              'assets/images/main_character1.png', // 이미지 경로
              width: 250, // 이미지 크기 조정
              height: 250, // 이미지 크기 조정
            ),
            const SizedBox(height: 20),
            // 텍스트 - "Hi, Guest"
            const Text(
              'Hi, Guest.',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0), // 텍스트 색상
              ),
            ),
            const SizedBox(height: 40),
            // 로그인 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ), // 로그인 페이지로 이동
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6E99), // 버튼 배경 색상
                foregroundColor: Colors.white, // 버튼 텍스트 색상
                minimumSize: const Size(200, 50), // 버튼 크기
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // 둥근 모서리 (30)
                ),
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            // 회원가입 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmailVerifyPage(),
                  ), // 회원가입 페이지로 이동
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE9DED4), // 버튼 배경 색상
                foregroundColor: const Color.fromARGB(
                  255,
                  0,
                  0,
                  0,
                ), // 버튼 텍스트 색상
                minimumSize: const Size(200, 50), // 버튼 크기
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // 둥근 모서리 (30)
                ),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            // sdffdfhp
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF88C999),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Test - All Users',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
