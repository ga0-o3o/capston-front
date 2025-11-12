import 'package:flutter/material.dart';
import 'signup_form.dart';
import 'package:gif_view/gif_view.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 248, 246),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // 상단 GIF
              Center(
                child: GifView.asset(
                  'assets/images/Saving_Cat1.gif',
                  height: 270,
                  frameRate: 6,
                  autoPlay: true,
                  loop: true,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              // 회원가입 카드 (폼)
              const SignupForm(),
            ],
          ),
        ),
      ),
    );
  }
}
