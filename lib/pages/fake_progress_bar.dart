import 'package:flutter/material.dart';
import 'dart:async';

class FakeProgressBar extends StatefulWidget {
  final double width; // 진행률 바 전체 너비
  final double height; // 진행률 바 높이
  final Color backgroundColor;
  final Color progressColor;
  final Duration duration; // 진행률 증가 속도

  const FakeProgressBar({
    Key? key,
    this.width = 200,
    this.height = 20,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.progressColor = const Color(0xFF4E6E99),
    this.duration = const Duration(milliseconds: 50),
  }) : super(key: key);

  @override
  State<FakeProgressBar> createState() => _FakeProgressBarState();
}

class _FakeProgressBarState extends State<FakeProgressBar> {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startFakeProgress();
  }

  void _startFakeProgress() {
    _timer = Timer.periodic(widget.duration, (timer) {
      setState(() {
        _progress += 1; // 1%씩 증가
        if (_progress >= 100) {
          _progress = 100;
          _timer?.cancel();
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: widget.width * (_progress / 100),
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.progressColor,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('${_progress.toInt()}%', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
