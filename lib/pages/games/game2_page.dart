import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Game2Page extends StatefulWidget {
  const Game2Page({Key? key}) : super(key: key);

  @override
  State<Game2Page> createState() => _Game2PageState();
}

class _Game2PageState extends State<Game2Page> {
  List<Map<String, dynamic>> words = [];
  Map<String, dynamic>? currentWord;
  bool showKorean = true;

  final TextEditingController controller = TextEditingController();
  String? userId;
  String? token;
  bool isLoading = true;

  final Random _random = Random();

  int totalTime = 120;
  DateTime? pauseStart;
  int questionNumber = 0;
  int lives = 3; // 목숨
  Timer? gameTimer;
  bool gameOver = false;

  List<Map<String, String>> submittedAnswers = [];

  @override
  void initState() {
    super.initState();
    _loadUserIdAndWords();
    _startTimer();
  }

  void _startTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel(); // 위젯이 없으면 타이머 중지
        return;
      }

      if (gameOver) {
        timer.cancel();
        return;
      }

      if (totalTime > 0) {
        setState(() {
          totalTime--;
        });
      } else {
        setState(() {
          gameOver = true;
        });
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("시간 종료! 게임 오버")),
        );
      }
    });
  }

  void checkAnswer() {
    if (currentWord == null || gameOver) return;

    final answer = currentWord!["wordEn"].toString();
    final meaning = currentWord!["koreanMeaning"].toString();
    final submitted = controller.text.trim();

    // 제시어가 포함되어 있는지 확인
    if (!submitted.toLowerCase().contains(answer.toLowerCase())) {
      lives--; // 목숨 감소
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("틀렸습니다! 제시어가 포함되어 있지 않습니다."),
        ),
      );

      if (lives <= 0) {
        setState(() {
          gameOver = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("목숨 소진! 게임 오버")),
        );
      }

      controller.clear();
      setState(() {});
      return; // 제시어 미포함이면 더 이상 진행하지 않음
    }

    // 정답인지 확인
    submittedAnswers.insert(0, {
      "word": answer,
      "meaning": meaning,
      "submitted": submitted,
    });

    if (submitted.toLowerCase() == answer.toLowerCase()) {
      _nextQuestion();
    } else {
      lives--; // 틀린 경우 목숨 감소
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("틀렸습니다!")),
      );

      if (lives <= 0) {
        setState(() {
          gameOver = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("목숨 소진! 게임 오버")),
        );
      }
    }

    controller.clear();
    setState(() {});
  }

  void _pauseGame() {
    // 타이머 멈춤
    gameTimer?.cancel();
    pauseStart = DateTime.now();

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
              _startTimer(); // 다시 타이머 시작
            },
            child: const Text("계속하기"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // 메뉴로 나가기
            },
            child: const Text("종료"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel(); // 타이머 중지
    controller.dispose(); // 텍스트 컨트롤러 정리
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

    await fetchWords(storedUserId, storedToken);
  }

  Future<void> fetchWords(String userId, String token) async {
    final url = Uri.parse("http://localhost:8080/api/personal-words/$userId");
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      setState(() {
        words = list;
        _nextQuestion();
        isLoading = false;
      });
    } else {
      print("단어 조회 실패: ${response.statusCode}");
      setState(() => isLoading = false);
    }
  }

  void _nextQuestion() {
    if (words.isEmpty) return;
    currentWord = words[_random.nextInt(words.length)];
    showKorean = _random.nextBool();
    questionNumber++;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("제시어 영작 게임"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 남은 시간과 목숨 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '남은 시간: $totalTime초',
                ),
                Row(
                  children: List.generate(
                    lives,
                    (index) => const Icon(Icons.favorite, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 문제 영역
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.black12,
              child: Stack(
                children: [
                  // 제시어 가운데 정렬
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      currentWord != null
                          ? '제시어: ${currentWord!["wordEn"]}'
                          : "단어 없음",
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // 오른쪽에 일시정지 버튼
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

            // 힌트 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (currentWord != null) {
                      final hint = currentWord!["koreanMeaning"] ?? "뜻 없음";
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("힌트: $hint"),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6E99), // 버튼 배경색
                    foregroundColor: Colors.white, // 글자색
                  ),
                  child: const Text("힌트"),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 정답 입력창 + 제출 버튼
            Column(
              children: [
                TextField(
                  controller: controller,
                  maxLines: null, // 문장 길이에 따라 여러 줄 입력 가능
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "정답 입력",
                  ),
                  onSubmitted: (_) => checkAnswer(), // Enter로 제출
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 150, // 원하는 가로 길이
                  height: 40, // 세로 길이
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

            // 제출된 답 보여주기
            Expanded(
              child: ListView.builder(
                itemCount: submittedAnswers.length,
                itemBuilder: (context, index) {
                  final item = submittedAnswers[index]; // 맨 위가 최신
                  return Card(
                    child: ListTile(
                      title: Text('제시어: ${item["word"]}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('뜻: ${item["meaning"]}'),
                          Text('답: ${item["submitted"]}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
