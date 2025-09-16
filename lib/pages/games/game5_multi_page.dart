import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';

// ------------------ 멀티 모드용 게임 로직 ------------------
class WordChainMultiGame extends FlameGame {
  List<String> usedWords = [];
  String currentWord = "";
  int scoreP1 = 0;
  int scoreP2 = 0;
  bool gameOver = false;
  int turn = 1; // 1: Player1, 2: Player2

  final List<String> wordBank = [
    "pasta", // a
    "club", // b
    "arc", // c
    "trend", // d
    "hope", // e
    "calf", // f
    "dog", // g
    "path", // h
    "ski", // i
    "jog", // j
    "kick", // k
    "goal", // l
    "drum", // m
    "sun", // n
    "photo", // o
    "top", // p
    "unique", // q
    "star", // r
    "bus", // s
    "cat", // t
    "menu", // u
    "navy", // v
    "show", // w
    "box", // x
    "day", // y
    "jazz", // z
  ];

  Random random = Random();

  void startGame() {
    usedWords.clear();
    gameOver = false;
    currentWord = wordBank[random.nextInt(wordBank.length)];
  }

  bool submitWord(String word) {
    word = word.toLowerCase().trim();
    if (word.isEmpty) return false;
    if (usedWords.contains(word)) return false;
    if (currentWord.isNotEmpty &&
        word[0] != currentWord[currentWord.length - 1]) return false;

    usedWords.insert(0, word);
    currentWord = word;

    if (turn == 1)
      scoreP1 += 10;
    else
      scoreP2 += 10;

    turn = turn == 1 ? 2 : 1; // 턴 교체
    return true;
  }
}

// ------------------ 게임 페이지 ------------------
class Game5MultiPage extends StatefulWidget {
  final List<String> userIds; // 플레이어 ID
  final List<String> tokens; // 플레이어 토큰

  const Game5MultiPage({
    Key? key,
    required this.userIds,
    required this.tokens,
  }) : super(key: key);

  @override
  State<Game5MultiPage> createState() => _Game5MultiPageState();
}

class _Game5MultiPageState extends State<Game5MultiPage> {
  late WordChainMultiGame game;
  final Map<String, TextEditingController> controllers = {};
  Timer? _timer;
  int remainingTime = 120;

  @override
  void initState() {
    super.initState();
    game = WordChainMultiGame();
    game.startGame();

    for (var userId in widget.userIds) {
      controllers[userId] = TextEditingController();
    }

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime <= 0 || game.gameOver) {
        timer.cancel();
        game.gameOver = true;
        _showGameOverDialog();
      } else {
        setState(() {
          remainingTime--;
        });
      }
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("게임 종료"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.userIds.map((u) {
            int score = (u == "P1" ? game.scoreP1 : game.scoreP2);
            return Text("$u: $score 점");
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  void _submitWord(String userId) {
    if (game.gameOver) return;

    bool success = game.submitWord(controllers[userId]?.text ?? "");
    controllers[userId]?.clear();
    setState(() {});

    if (!success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("잘못된 단어입니다!")));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("끝말잇기 (멀티)"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("남은 시간: $remainingTime s"),
            const SizedBox(height: 8),
            Text("턴: ${game.turn == 1 ? "Player 1" : "Player 2"}"),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.userIds.map((u) {
                int score = (u == "P1" ? game.scoreP1 : game.scoreP2);
                return Text("$u: $score");
              }).toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: widget.userIds.map((u) {
                  return Column(
                    children: [
                      TextField(
                        controller: controllers[u],
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: "$u 단어 입력",
                        ),
                        onSubmitted: (_) => _submitWord(u),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _submitWord(u),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E6E99),
                        ),
                        child: const Text("제출"),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: game.usedWords
                    .map((w) => ListTile(title: Text(w)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
