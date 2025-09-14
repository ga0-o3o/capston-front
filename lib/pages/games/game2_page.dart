import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class Game2 extends FlameGame {
  int score = 0;
  int timeLeft = 30;
  String currentWord = '';
  Timer? _timer;

  final List<String> wordList = [
    'apple',
    'future',
    'travel',
    'dream',
    'challenge',
  ];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _nextWord();
    _startTimer();
  }

  void _nextWord() {
    currentWord = (wordList..shuffle()).first;
    overlays.add('inputOverlay');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timeLeft--;
      if (timeLeft <= 0) {
        timer.cancel();
        overlays.add('gameOver');
      }
    });
  }

  void checkSentence(String sentence) {
    // 🔹 아주 단순한 체크: 제시어 포함 여부만 (문법 API로 대체 가능)
    if (sentence.toLowerCase().contains(currentWord.toLowerCase())) {
      score++;
    }
    // 다음 제시어
    _nextWord();
  }

  @override
  void onRemove() {
    _timer?.cancel();
    super.onRemove();
  }
}

class Game2Page extends StatelessWidget {
  const Game2Page({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final game = Game2();

    return Scaffold(
      // 🔹 전체 배경색
      backgroundColor: const Color(0xFFF6F0E9),

      appBar: AppBar(
        title: const Text("제시어 영작 게임"),
        // 🔹 AppBar 색상
        backgroundColor: const Color(0xFF4E6E99),
      ),

      body: GameWidget(
        game: game,
        overlayBuilderMap: {
          'inputOverlay': (_, Game2 game) => _InputOverlay(game: game),
          'gameOver': (_, Game2 game) => _GameOverOverlay(score: game.score),
        },
      ),
    );
  }
}

class _InputOverlay extends StatefulWidget {
  final Game2 game;
  const _InputOverlay({required this.game});
  @override
  State<_InputOverlay> createState() => _InputOverlayState();
}

class _InputOverlayState extends State<_InputOverlay> {
  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('제시어: ${widget.game.currentWord}'),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '제시어를 포함한 문장을 입력하세요',
                ),
                onSubmitted: (value) {
                  widget.game.checkSentence(value);
                  controller.clear();
                },
              ),
              Text('남은 시간: ${widget.game.timeLeft}초'),
              Text('점수: ${widget.game.score}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final int score;
  const _GameOverOverlay({required this.score});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AlertDialog(
        title: const Text('게임 종료'),
        content: Text('총 점수: $score'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
