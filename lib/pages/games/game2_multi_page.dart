import 'dart:async';
import 'package:flutter/material.dart';

class Game2MultiPage extends StatefulWidget {
  final List<String> userIds;
  final String hostToken;

  const Game2MultiPage({
    Key? key,
    required this.userIds,
    required this.hostToken,
  }) : super(key: key);

  @override
  State<Game2MultiPage> createState() => _Game2MultiPageState();
}

class _Game2MultiPageState extends State<Game2MultiPage> {
  List<Map<String, dynamic>> submittedAnswers = [];
  int totalTime = 120;
  int lives = 3;
  Timer? gameTimer;
  bool gameOver = false;

  // 플레이어 구분 (멀티 플레이어용)
  int currentPlayer = 1;
  Map<int, int> playerScores = {1: 0, 2: 0};

  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || gameOver) {
        timer.cancel();
        return;
      }

      if (totalTime > 0) {
        setState(() => totalTime--);
      } else {
        _endGame();
      }
    });
  }

  void checkAnswer() {
    if (gameOver) return;

    final submitted = controller.text.trim();

    if (submitted.isEmpty) return;

    // 점수 예제: 단어 수 기준
    int score = submitted.split(RegExp(r'\s+')).length;

    setState(() {
      submittedAnswers.add({
        "player": currentPlayer,
        "submitted": submitted,
        "score": score,
      });

      // 플레이어 점수 누적
      playerScores[currentPlayer] = (playerScores[currentPlayer] ?? 0) + score;

      // 다음 플레이어로 변경 (예: 2인 모드)
      currentPlayer = currentPlayer == 1 ? 2 : 1;

      controller.clear();
    });
  }

  void _endGame() {
    gameTimer?.cancel();
    setState(() => gameOver = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("게임 종료"),
        content: Text(
            "게임이 종료되었습니다!\n총 제출한 답: ${submittedAnswers.length}개\n플레이어1 점수: ${playerScores[1]}\n플레이어2 점수: ${playerScores[2]}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("제시어 영작 게임 (솔로 모드)"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('남은 시간: $totalTime초'),
            const SizedBox(height: 8),
            Text('현재 플레이어: $currentPlayer'),
            Text('플레이어1 점수: ${playerScores[1]}'),
            Text('플레이어2 점수: ${playerScores[2]}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "정답 입력",
              ),
              onSubmitted: (_) => checkAnswer(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 150,
              height: 40,
              child: ElevatedButton(
                onPressed: checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99),
                ),
                child: const Text("제출"),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: submittedAnswers.length,
                itemBuilder: (context, index) {
                  final item = submittedAnswers[index];
                  return ListTile(
                    title: Text("플레이어${item['player']}: ${item['submitted']}"),
                    trailing: Text("점수: ${item['score']}"),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
