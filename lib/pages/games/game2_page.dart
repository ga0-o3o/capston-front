import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../loading_page.dart';
import 'game_api.dart';
import 'game_dialogs.dart';
import '../word/word_item.dart';
import '../word/word_api.dart';

class Game2Page extends StatefulWidget {
  const Game2Page({Key? key}) : super(key: key);

  @override
  State<Game2Page> createState() => _Game2PageState();
}

class _Game2PageState extends State<Game2Page> {
  List<Map<String, dynamic>> words = [];
  Map<String, dynamic>? currentWord;

  final TextEditingController controller = TextEditingController();
  String? userId;
  String? token;
  bool isLoading = true;

  final Random _random = Random();

  int totalTime = 120;
  int questionNumber = 0;
  int lives = 3;
  Timer? gameTimer;
  bool gameOver = false;

  int lastScore = 0;
  int totalScore = 0;

  List<Map<String, dynamic>> submittedAnswers = [];

  @override
  void initState() {
    super.initState();
    _loadUserIdAndWords();
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

  Future<List<Map<String, String>>> checkGrammar(String sentence) async {
    final url = Uri.parse("https://api.sapling.ai/api/v1/edits");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer 3HFZSH7A9O05TM0Q0SZRA7CB657WEH7B",
        },
        body: jsonEncode({
          "text": sentence,
          "session_id": "game_session_1",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final edits = data["edits"] as List;

        return edits.map<Map<String, String>>((e) {
          final wrongText = sentence.substring(
            e["start"] as int,
            (e["end"] as int).clamp(0, sentence.length),
          );

          final replacement = (e["replacements"] as List?)?.isNotEmpty == true
              ? e["replacements"][0]
              : "Error";

          return {
            "wrongText": wrongText,
            "message": replacement,
          };
        }).toList();
      } else {
        print("Sapling API error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Sapling API exception: $e");
      return [];
    }
  }

  void checkAnswer() async {
    if (currentWord == null || gameOver) return;

    final answer = currentWord!["wordEn"].toString();
    final meaning = currentWord!["koreanMeaning"].toString();
    final submitted = controller.text.trim();

    List<Map<String, String>> grammarDetails = [];

    if (!submitted.toLowerCase().contains(answer.toLowerCase())) {
      setState(() {
        lives--;
        lastScore = 0;

        submittedAnswers.insert(0, {
          "word": answer,
          "meaning": meaning,
          "submitted": submitted,
          "grammarErrors": 0,
          "grammarDetails": [],
          "score": lastScore,
        });

        _nextQuestion();
      });

      if (lives <= 0) _endGame();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("틀렸습니다! 제시어가 포함되어 있지 않습니다. 목숨 -1"),
        ),
      );

      controller.clear();
      return;
    }

    grammarDetails = await checkGrammar(submitted);

    int score = 0;

    if (grammarDetails.isEmpty) {
      score = submitted.split(RegExp(r'\s+')).length;
      totalScore += score;
    } else {
      setState(() => lives--);
      if (lives <= 0) _endGame();
    }

    setState(() {
      lastScore = score;
      submittedAnswers.insert(0, {
        "word": answer,
        "meaning": meaning,
        "submitted": submitted,
        "grammarErrors": grammarDetails.length,
        "grammarDetails": grammarDetails,
        "score": lastScore,
      });

      _nextQuestion();
    });

    if (grammarDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("정답! 문법도 OK, 점수: $lastScore")),
      );
    } else {
      if (lives > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "문법 오류 ${grammarDetails.length}개! 목숨 -1, 점수: $lastScore",
            ),
          ),
        );
      }
    }

    controller.clear();
  }

  void _endGame() {
    gameTimer?.cancel();
    setState(() => gameOver = true);

    int totalSubmitted = submittedAnswers.length;
    int totalScoreCalc =
        submittedAnswers.fold(0, (sum, item) => sum + (item["score"] as int));

    showGameOverDialog_game2(
      context: context,
      totalScore: totalScoreCalc,
      remainingLives: lives,
      totalSubmitted: totalSubmitted,
      onConfirm: () => Navigator.pop(context),
    );
  }

  void _pauseGame() {
    gameTimer?.cancel();

    showPauseDialog(
      context: context,
      onResume: () {
        _startTimer();
      },
      onExit: () {
        Navigator.pop(context);
      },
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndWords() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('jwt_token');
    final storedUserId = prefs.getString('user_id');

    if (storedUserId == null || storedToken == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() {
      userId = storedUserId;
      token = storedToken;
    });

    List<WordItem> allWords = [];
    try {
      allWords = await GameApi.fetchAllWords(storedUserId);
    } catch (e) {
      print("전체 단어 가져오기 예외: $e");
    }

    setState(() {
      words = allWords
          .map((w) => {
                "wordEn": w.word,
                "koreanMeaning": w.wordKr.join(", "),
              })
          .toList();

      // 🔥 단어 비어있으면 오버레이 표시 + 3초 후 뒤로가기
      if (words.isEmpty) {
        isLoading = false;
        Future.delayed(Duration.zero, () {
          _showNoWordsOverlay();
        });
        return;
      }

      _nextQuestion();
      isLoading = false;
    });
  }

  void _showNoWordsOverlay() {
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Container(
          color: Colors.white.withOpacity(0.85), // 🔥 흰색 반투명
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Text(
                "단어장에 단어가 있지 않습니다.\n단어를 추가하여서\n게임을 진행해주세요.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    // ⏳ 3초 후 자동 종료 + 뒤로가기
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
      if (mounted) Navigator.pop(context);
    });
  }

  void _nextQuestion() {
    if (words.isEmpty) return;
    currentWord = words[_random.nextInt(words.length)];
    questionNumber++;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingPage();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("제시어 영작 게임"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('남은 시간: $totalTime초'),
                Row(
                  children: List.generate(
                    lives,
                    (index) => const Icon(Icons.favorite, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.black12,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      currentWord != null
                          ? '제시어: ${currentWord!["wordEn"]}'
                          : "단어 없음",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.pause, size: 28),
                      onPressed: _pauseGame,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '점수: $totalScore',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // 🔥 서버에서 모든 뜻을 가져오는 힌트 버튼
                ElevatedButton(
                  onPressed: () async {
                    if (currentWord == null) return;

                    try {
                      final wordEn = currentWord!["wordEn"];
                      final meanings = await WordApi.checkQuiz(wordEn);
                      final hint = meanings.join(", ");

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("힌트: $hint"),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("뜻을 불러오지 못했습니다."),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6E99),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("힌트"),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 입력 영역
            Column(
              children: [
                TextField(
                  controller: controller,
                  maxLines: null,
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
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "제출",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 제출 기록
            Expanded(
              child: ListView.builder(
                itemCount: submittedAnswers.length,
                itemBuilder: (context, index) {
                  final item = submittedAnswers[index];

                  return InkWell(
                    onTap: () {
                      if (item["grammarErrors"] > 0) {
                        final details =
                            item["grammarDetails"] as List<Map<String, String>>;

                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("문법 오류 상세"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: details
                                  .map((d) => Text(
                                      "틀린 부분: '${d["wrongText"]}' → ${d["message"]}"))
                                  .toList(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("닫기"),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFF4E6E99), width: 5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '제시어: ${item["word"]}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('뜻: ${item["meaning"]}'),
                          Text('답: ${item["submitted"]}'),
                          Text('문법 오류: ${item["grammarErrors"]}개'),
                          if (item["grammarErrors"] > 0)
                            const Text(
                              "(클릭하면 상세 오류 확인)",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
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
