import 'package:flutter/material.dart';
import 'signup_form.dart';

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
                child: Image.asset(
                  'assets/images/Saving_Cat1.gif',
                  width: 320,
                  height: 320,
                  gaplessPlayback: true,
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
