import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  String fullText = "복습할 단어 조회 중...";
  String displayedText = "";
  int currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTextAnimation();
  }

  void _startTextAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        if (currentIndex < fullText.length) {
          displayedText += fullText[currentIndex];
          currentIndex++;
        } else {
          // 글자 모두 출력 후 초기화
          displayedText = "";
          currentIndex = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GifView.asset(
              'assets/images/review_cat1.gif',
              height: 300,
              frameRate: 18,
              autoPlay: true,
              loop: true,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              displayedText,
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
