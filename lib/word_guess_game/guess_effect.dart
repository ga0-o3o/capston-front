// guess_effect.dart
import 'package:flutter/material.dart';

enum GuessResultType {
  hadIt,
  missedIt,
}

class GuessEffectPage extends StatefulWidget {
  final GuessResultType resultType;
  final Duration duration;
  final VoidCallback? onFinished;

  const GuessEffectPage({
    super.key,
    required this.resultType,
    this.duration = const Duration(seconds: 2),
    this.onFinished,
  });

  @override
  State<GuessEffectPage> createState() => _GuessEffectPageState();
}

class _GuessEffectPageState extends State<GuessEffectPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 🔹 Scale: 0 → 1.2(팡!) → 1.0 → 0 (사라짐)
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25, // 처음 25% 구간 팡!
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25, // 살짝 줄어들어 안정
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50, // 마지막에 작아지면서 사라짐
      ),
    ]).animate(_controller);

    // 🔹 Fade: 처음엔 1, 끝 30% 구간에서 0으로 사라짐
    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween(1.0), // 앞부분은 1 유지
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        widget.onFinished?.call();
        Navigator.of(context).pop();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWinner = widget.resultType == GuessResultType.hadIt;
    final String imagePath = isWinner
        ? 'assets/images/you_had_it.png'
        : 'assets/images/you_missed_it.png';

    return Scaffold(
      backgroundColor: Colors.white38,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
            const Text(
              'Waiting for next round...',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
