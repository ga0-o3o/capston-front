import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ------------------- 단어 빨리 맞히기 게임 로직 -----------------
class FastWordGame extends FlameGame {
  List<Map<String, dynamic>> wordBank = [];
  Map<String, dynamic>? currentWord;
  int score = 0;
  int lives = 3;
  bool gameOver = false;
  List<String> submittedWords = [];
  Random random = Random();
  VoidCallback? onUpdate;

  void startGame(List<Map<String, dynamic>> words) {
    wordBank = words;
    score = 0;
    lives = 3;
    submittedWords.clear();
    gameOver = false;
    _nextWord();
    onUpdate?.call();
  }

  void _nextWord() {
    if (wordBank.isEmpty) return;
    currentWord = wordBank[random.nextInt(wordBank.length)];
  }

  Future<void> submitWord(String word, BuildContext context) async {
    if (gameOver || currentWord == null) return;

    word = word.toLowerCase().trim();
    if (word.isEmpty) return;

    String correctWord =
        (currentWord!["wordEn"] ?? "").toString().toLowerCase();

    if (word != correctWord) {
      lives--;
      if (lives <= 0) gameOver = true;
      onUpdate?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("틀린 단어: $word. 남은 목숨: $lives"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    submittedWords.insert(0, word);
    int position = submittedWords.length - 1;
    int earnedScore = max(5 - position, 0);
    score += earnedScore;

    _nextWord();
    onUpdate?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("정답! +$earnedScore 점"),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ----------------- 게임 페이지 -----------------
class Game1Page extends StatefulWidget {
  const Game1Page({Key? key}) : super(key: key);

  @override
  State<Game1Page> createState() => _Game1PageState();
}

class _Game1PageState extends State<Game1Page> {
  late FastWordGame game;
  final TextEditingController controller = TextEditingController();
  Timer? _timer;
  int remainingTime = 30;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    game = FastWordGame();
    game.onUpdate = () {
      setState(() {});
    };
    _fetchWordsAndStart();
  }

  Future<void> _fetchWordsAndStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final userId = prefs.getString('user_id') ?? '';

      if (token.isEmpty || userId.isEmpty) {
        throw Exception("토큰 또는 사용자 ID가 없습니다. 로그인 먼저 필요");
      }

      final url = Uri.parse("http://localhost:8080/api/personal-words/$userId");
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> words =
            List<Map<String, dynamic>>.from(jsonDecode(response.body));
        game.startGame(words); // 게임 시작
      } else {
        throw Exception("단어장 가져오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("단어장 불러오기 실패: $e");
    }
  }

  void startTimer() {
    _timerStarted = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0 && !game.gameOver) {
        setState(() => remainingTime--);
      } else {
        timer.cancel();
        if (!game.gameOver) game.gameOver = true;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("시간 종료! 게임 오버!")));
      }
    });
  }

  void startWordTimer() {
    _timer?.cancel();
    remainingTime = 30;
    _timerStarted = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0 && !game.gameOver) {
        setState(() => remainingTime--);
      } else {
        timer.cancel();
        if (!game.gameOver) {
          game.gameOver = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("시간 초과! 게임 오버!")),
          );
        }
      }
    });
  }

  void checkAnswer() async {
    if (!_timerStarted) startTimer();
    await game.submitWord(controller.text, context);
    controller.clear();
    if (game.gameOver) _timer?.cancel();
  }

  void _pauseGame() {
    _timer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("일시정지"),
        content: const Text("게임을 계속하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (!_timerStarted && !game.gameOver) startTimer();
            },
            child: const Text("계속하기"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("종료"),
          ),
        ],
      ),
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
        title: const Text("단어 빨리 맞히기"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    game.currentWord?["koreanMeaning"] ?? "",
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("점수: ${game.score}", style: const TextStyle(fontSize: 20)),
                Text("남은 시간: $remainingTime s"),
              ],
            ),
            const SizedBox(height: 16),
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
            ElevatedButton(
              onPressed: checkAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6E99),
                foregroundColor: Colors.white,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text("제출"),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: game.submittedWords
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
