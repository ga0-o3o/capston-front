import 'package:flutter/material.dart';

class BingoEffect extends StatefulWidget {
  /// 빙고 효과용 (1,2,3빙고)
  final int? bingoCount;

  /// 퀴즈 정답 여부용
  ///  - true  => assets/images/correct.png
  ///  - false => assets/images/failure.png
  ///  - null  => 빙고 모드로 동작
  final bool? isCorrect;

  final VoidCallback? onEnd;

  const BingoEffect({
    Key? key,
    this.bingoCount,
    this.isCorrect,
    this.onEnd,
  }) : super(key: key);

  @override
  State<BingoEffect> createState() => _BingoEffectState();
}

class _BingoEffectState extends State<BingoEffect>
    with SingleTickerProviderStateMixin {
  double _scale = 0.2;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();

    // 등장 → 확대 → 사라짐
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() => _scale = 1.5);
    });

    // 1.5초 후 서서히 사라짐
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _opacity = 0);
    });

    // 2초 후 종료 콜백
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      widget.onEnd?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 이미지 경로 결정 로직
    // 1) isCorrect가 정해져 있으면 퀴즈 모드
    // 2) 아니면 기존 빙고 모드
    final String imagePath;
    if (widget.isCorrect != null) {
      imagePath = widget.isCorrect!
          ? 'assets/images/correct.png'
          : 'assets/images/failure.png';
    } else {
      final count = (widget.bingoCount ?? 1).clamp(1, 3);
      imagePath = switch (count) {
        1 => 'assets/images/1bingo.png',
        2 => 'assets/images/2bingo.png',
        _ => 'assets/images/3bingo.png',
      };
    }

    return Center(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 500),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          child: Image.asset(
            imagePath,
            width: MediaQuery.of(context).size.width * 0.6,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
