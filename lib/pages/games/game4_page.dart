import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'game_dialogs.dart';

// ------------------- 단어 존재 확인 -------------------
Future<bool> checkWordExists(String word) async {
  final url = Uri.parse('https://api.datamuse.com/words?sp=$word&max=1');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body);
    return data.isNotEmpty;
  } else {
    throw Exception('API 요청 실패');
  }
}

// ------------------- 단어 뜻 확인 -------------------
Future<bool> checkWordHasDefinition(String word) async {
  final url = Uri.parse(
    'https://api.dictionaryapi.dev/api/v2/entries/en/$word',
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body);
    if (data.isEmpty) return false;

    for (var meaning in data[0]['meanings']) {
      if (meaning['definitions'] != null && meaning['definitions'].isNotEmpty) {
        return true;
      }
    }
    return false;
  } else {
    return false;
  }
}

// ----------------- 끝말잇기 게임 로직 -----------------
class WordChainGame extends FlameGame {
  List<String> usedWords = [];
  String currentWord = "";
  int score = 0;
  int lives = 3; // 목숨 3개
  bool gameOver = false;

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

  VoidCallback? onUpdate;
  Random random = Random();

  void startGame() {
    score = 0;
    lives = 3;
    usedWords.clear();
    gameOver = false;
    currentWord = wordBank[random.nextInt(wordBank.length)];
    onUpdate?.call();
  }

  Future<void> submitWordWithCheck(String word, BuildContext context) async {
    if (gameOver) return;

    word = word.toLowerCase().trim();
    if (word.isEmpty) return;

    // 이미 사용한 단어 체크
    if (usedWords.contains(word)) {
      lives--;
      if (lives <= 0) gameOver = true;
      onUpdate?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("이미 사용한 단어입니다: $word. 남은 목숨: $lives"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 끝말잇기 규칙 위반 체크
    if (currentWord.isNotEmpty &&
        word[0] != currentWord[currentWord.length - 1]) {
      lives--;
      if (lives <= 0) gameOver = true;
      onUpdate?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("끝말잇기 규칙 위반! 단어: $word. 남은 목숨: $lives"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 단어 존재 및 뜻 확인
    bool exists = await checkWordExists(word);
    bool hasDef = await checkWordHasDefinition(word);

    if (!exists || !hasDef) {
      lives--;
      if (lives <= 0) gameOver = true;
      onUpdate?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("사용 불가 단어입니다: $word. 남은 목숨: $lives"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 정상 단어
    usedWords.insert(0, word);
    currentWord = word;
    score += 10;
    onUpdate?.call();
  }
}

// ----------------- 게임 페이지 -----------------
class Game4Page extends StatefulWidget {
  const Game4Page({Key? key}) : super(key: key);

  @override
  State<Game4Page> createState() => _Game4PageState();
}

class _Game4PageState extends State<Game4Page> {
  late WordChainGame game;
  final TextEditingController controller = TextEditingController();

  Timer? _timer;
  int remainingTime = 120;
  bool _timerStarted = false;

  DateTime? pauseStart;

  @override
  void initState() {
    super.initState();
    game = WordChainGame();
    game.onUpdate = () {
      setState(() {});
    };
    game.startGame();
  }

  void startTimer() {
    _timerStarted = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0 && !game.gameOver) {
        setState(() {
          remainingTime--;
        });
      } else {
        timer.cancel();
        if (!game.gameOver) {
          setState(() {
            game.gameOver = true;
          });
          // 시간 종료 시 다이얼로그
          showGameOverDialog_game4(
            context: context,
            success: false,
            score: game.score,
            usedWordCount: game.usedWords.length,
            onConfirm: () {
              Navigator.pop(context); // 이전 화면으로 이동
            },
          );
        }
      }
    });
  }

  void checkAnswer() async {
    if (game.gameOver) return;

    if (!_timerStarted) startTimer();

    await game.submitWordWithCheck(controller.text, context);
    controller.clear();

    if (game.gameOver) {
      _timer?.cancel();

      // 기존 스낵바 제거
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 게임 오버 다이얼로그 띄우기
      showGameOverDialog_game4(
        context: context,
        success: false, // 끝말잇기 게임에서는 success 구분 없으므로 false
        score: game.score,
        usedWordCount: game.usedWords.length,
        onConfirm: () {
          Navigator.pop(context); // 게임 화면 종료 → 이전 화면 복귀
        },
      );
    }
  }

  void _pauseGame() {
    _timer?.cancel(); // 타이머 일시정지

    showPauseDialog(
      context: context,
      onResume: () {
        startTimer(); // 타이머 그대로 재개
      },
      onExit: () {
        Navigator.pop(context); // 게임 화면 종료
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        title: const Text("개인 영단어 끝말잇기 (솔로 모드)"),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 현재 단어 + 일시정지
            Container(
              width: double.infinity,
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 가운데 단어 (맨 마지막 글자 빨간색)
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(
                          text: game.currentWord.length > 1
                              ? game.currentWord.substring(
                                  0,
                                  game.currentWord.length - 1,
                                )
                              : "",
                        ),
                        TextSpan(
                          text: game.currentWord.isNotEmpty
                              ? game.currentWord[game.currentWord.length - 1]
                              : "",
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  // 오른쪽 일시정지 버튼
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.pause, size: 28),
                      onPressed: _pauseGame, // 기존 startTimer 대신 호출
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 점수 및 남은 시간
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("점수: ${game.score}", style: const TextStyle(fontSize: 20)),
                Row(
                  children: [
                    Text("남은 시간: $remainingTime s"),
                    const SizedBox(width: 16),
                    Row(
                      children: List.generate(
                        game.lives,
                        (index) => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                          child: Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 단어 입력
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "단어 입력",
              ),
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
                checkAnswer();
              },
            ),
            const SizedBox(height: 16),

            // 제출 버튼
            ElevatedButton(
              onPressed: checkAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6E99),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text("제출"),
            ),
            const SizedBox(height: 16),

            // 사용된 단어 목록
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
