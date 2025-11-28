import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'game_dialogs.dart';

/// ------------------- 단어 유효성 검사 -------------------
/// dictionaryapi.dev 를 사용해서:
///  - HTTP 200 이고
///  - meanings 안에 definitions 가 1개 이상 있으면
///    => "정상 영어 단어" 로 인정
Future<bool> checkWordValid(String word) async {
  try {
    final url =
        Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word');
    final response = await http.get(url);

    // 200 이 아니면(404 포함) 바로 실패 처리
    if (response.statusCode != 200) {
      debugPrint(
          'Dictionary API status: ${response.statusCode} body: ${response.body}');
      return false;
    }

    final data = jsonDecode(response.body);

    // 응답이 List 형태가 아니거나 비어 있으면 실패
    if (data is! List || data.isEmpty) return false;

    final first = data[0];
    final meanings = first['meanings'];

    if (meanings is! List) return false;

    // meanings 안에 definitions 가 하나라도 있으면 유효한 단어
    for (final meaning in meanings) {
      final defs = meaning['definitions'];
      if (defs is List && defs.isNotEmpty) {
        return true;
      }
    }

    return false;
  } catch (e, st) {
    debugPrint('checkWordValid error: $e\n$st');
    // 네트워크 에러 / JSON 파싱 에러 등은 "유효하지 않은 단어"로 처리
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
    "magic", // c
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

  /// 성공이면 null 리턴, 실패하면 에러 메시지(String) 리턴
  Future<String?> submitWordWithCheck(String word) async {
    if (gameOver) return null;

    word = word.toLowerCase().trim();
    if (word.isEmpty) return null;

    // 이미 사용한 단어 체크
    if (usedWords.contains(word)) {
      lives--;
      if (lives <= 0) gameOver = true;
      onUpdate?.call();
      return "이미 사용한 단어입니다: $word. 남은 목숨: $lives";
    }

    // 끝말잇기 규칙 위반 체크
    if (currentWord.isNotEmpty &&
        word[0] != currentWord[currentWord.length - 1]) {
      lives--;
      if (lives <= 0) gameOver = true;
      onUpdate?.call();
      return "끝말잇기 규칙 위반! 단어: $word. 남은 목숨: $lives";
    }

    // dictionaryapi.dev 로 단어 유효성 검사
    final isValid = await checkWordValid(word);

    if (!isValid) {
      lives--;
      if (lives <= 0) gameOver = true;
      onUpdate?.call();
      return "사용 불가 단어입니다: $word. 남은 목숨: $lives";
    }

    // 정상 단어
    usedWords.insert(0, word);
    currentWord = word;
    score += 10;
    onUpdate?.call();

    return null; // 성공
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

  @override
  void initState() {
    super.initState();
    game = WordChainGame();
    game.onUpdate = () {
      if (!mounted) return;
      setState(() {});
    };
    game.startGame();
  }

  void startTimer() {
    _timerStarted = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

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
          showGameOverDialog_game4(
            context: context,
            success: false,
            score: game.score,
            usedWordCount: game.usedWords.length,
            onConfirm: () {
              Navigator.pop(context);
            },
          );
        }
      }
    });
  }

  void checkAnswer() async {
    if (game.gameOver) return;

    if (!_timerStarted) startTimer();

    final msg = await game.submitWordWithCheck(controller.text);
    if (!mounted) return;

    controller.clear();

    // 에러/안내 메시지 있으면 스낵바 출력
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (game.gameOver) {
      _timer?.cancel();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      showGameOverDialog_game4(
        context: context,
        success: false,
        score: game.score,
        usedWordCount: game.usedWords.length,
        onConfirm: () {
          Navigator.pop(context);
        },
      );
    }
  }

  void _pauseGame() {
    _timer?.cancel(); // 타이머 일시정지

    showPauseDialog(
      context: context,
      onResume: () {
        startTimer(); // 타이머 재개
      },
      onExit: () {
        Navigator.pop(context); // 게임 화면 종료
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    game.onUpdate = null;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        title: const Text("개인 영단어 끝말잇기"),
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
                      onPressed: _pauseGame,
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
