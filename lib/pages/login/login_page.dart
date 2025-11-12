import 'package:flutter/material.dart';
import 'login_form.dart';
import 'sns_login.dart';
import 'package:gif_view/gif_view.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6),
      body: SafeArea(
        child: Center(
          // <- 화면 중앙 정렬
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center, // 가운데 정렬
              children: [
                const SizedBox(height: 30),
                GifView.asset(
                  'assets/images/covering_cat1.gif',
                  height: 220,
                  frameRate: 13,
                  autoPlay: true,
                  loop: true,
                  fit: BoxFit.contain,
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
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const LoginForm(),
                  ),
                ),
                const SizedBox(height: 20),
                const SNSLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
