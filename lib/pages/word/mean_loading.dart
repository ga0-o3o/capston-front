// word_loading.dart
import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';

class MeanLoadingPage extends StatefulWidget {
  final Future<void> Function() task;

  const MeanLoadingPage({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  State<MeanLoadingPage> createState() => _MeanLoadingPageState();
}

class _MeanLoadingPageState extends State<MeanLoadingPage> {
  @override
  void initState() {
    super.initState();
    // 화면이 완전히 그려진 뒤에 task 실행
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.task();
      } finally {
        if (mounted) {
          Navigator.of(context).pop(); // 작업 끝나면 이전 화면으로 복귀
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GifView.asset(
              'assets/images/background/mean_cat1.gif',
              width: 430,
              height: 430,
              frameRate: 12,
              autoPlay: true,
              loop: true,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              '뜻 조회 중...',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
