import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

// 멀티 모드용 Game 클래스 (지금은 빈 상태)
class Game6Multi extends FlameGame {
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // TODO: 멀티 모드 초기화 로직
  }

  @override
  void update(double dt) {
    super.update(dt);
    // TODO: 멀티 모드 게임 업데이트 로직
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // TODO: 멀티 모드 게임 화면 렌더링
  }
}

// ------------------ 게임 페이지 ------------------
class Game6MultiPage extends StatefulWidget {
  final List<String> userIds; // 플레이어 이름
  final String hostToken;

  const Game6MultiPage({
    Key? key,
    required this.userIds,
    required this.hostToken,
  }) : super(key: key);

  @override
  State<Game6MultiPage> createState() => _Game6MultiPageState();
}

class _Game6MultiPageState extends State<Game6MultiPage> {
  late Game6Multi game;

  int totalTime = 120;
  int lives = 3;
  bool gameOver = false;
  Timer? gameTimer;

  @override
  void initState() {
    super.initState();
    game = Game6Multi();
    _startGameTimer();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  void _startGameTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (gameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        totalTime--;
        if (totalTime <= 0) {
          gameOver = true;
          timer.cancel();
          _showGameOverDialog();
        }
      });
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("게임 종료"),
        content: const Text("멀티 모드 게임이 종료되었습니다."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog 닫기
              Navigator.pop(context); // 게임 화면 닫기
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("단어 타워 쌓기 (멀티)"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Column(
        children: [
          // 상단 정보바 (시간 + 목숨)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("총 시간: ${totalTime}s"),
                Row(
                  children: List.generate(
                    lives,
                    (index) => const Icon(Icons.favorite, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

          // 게임 영역
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black12,
                border: Border.all(color: Colors.black, width: 5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GameWidget(game: game),
            ),
          ),
        ],
      ),
    );
  }
}
