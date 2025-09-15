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
  int questionNumber = 0;
  int lives = 3; // 목숨
  Timer? gameTimer;
  bool gameOver = false;

  int lastScore = 0;
  int totalScore = 0;

  /// grammarDetails: List<Map<String, String>> 형태로 오류 메시지와 틀린 단어 저장
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
        _endGame(); // 시간 종료 시 게임 종료
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
          "Authorization": "Bearer 3HFZSH7A9O05TM0Q0SZRA7CB657WEH7B", // 여기!
        },
        body: jsonEncode({
          "text": sentence,
          "session_id": "game_session_1", // 아무 문자열 가능
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

          // replacements 배열에서 첫 번째 추천 수정 가져오기
          final replacement = (e["replacements"] as List?)?.isNotEmpty == true
              ? e["replacements"][0]
              : "Error";

          return {
            "wrongText": wrongText,
            "message": replacement, // 기존 message 대신 추천 수정 표시
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

    // 제시어 포함 여부 확인
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
        const SnackBar(content: Text("틀렸습니다! 제시어가 포함되어 있지 않습니다. 목숨 -1")),
      );

      controller.clear();
      return;
    }

    // 문법 체크
    grammarDetails = await checkGrammar(submitted);

    int score = 0;

    if (grammarDetails.isEmpty) {
      // 문법 오류 없을 때만 점수 부여
      score = submitted.split(RegExp(r'\s+')).length; // 띄어쓰기 기준 단어 수
      totalScore += score;
    } else {
      // 문법 오류 있을 경우 목숨 감소
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

    // 피드백 메시지
    if (grammarDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("정답! 문법도 OK, 점수: $lastScore")), // 띄어쓰기 기준 점수 표시
      );
    } else {
      if (lives > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "문법 오류 ${grammarDetails.length}개 발견! 목숨 -1, 점수: $lastScore")),
        );
      }
    }

    controller.clear();
  }

  void _endGame() {
    gameTimer?.cancel();
    setState(() => gameOver = true);

    // 총 점수 계산
    int totalScore =
        submittedAnswers.fold(0, (sum, item) => sum + (item["score"] as int));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("게임 종료"),
        content: Text(
            "게임이 종료되었습니다!\n남은 목숨: $lives\n총 제출한 답: ${submittedAnswers.length}개\n총 점수: $totalScore"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog 닫기
              Navigator.pop(context); // 게임 화면 종료
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  void _pauseGame() {
    gameTimer?.cancel();

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
              _startTimer();
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
        title: const Text("제시어 영작 게임 (솔로 모드)"),
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
                          fontSize: 24, fontWeight: FontWeight.bold),
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
                Text('점수: $totalScore',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
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
                    backgroundColor: const Color(0xFF4E6E99),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("힌트"),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: submittedAnswers.length,
                itemBuilder: (context, index) {
                  final item = submittedAnswers[index];

                  /// ✅ grammarErrors > 0 인 경우 클릭 시 다이얼로그
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
                              )
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
                          Text('제시어: ${item["word"]}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('뜻: ${item["meaning"]}'),
                          Text('답: ${item["submitted"]}'),
                          Text('문법 오류: ${item["grammarErrors"]}개'),
                          if (item["grammarErrors"] > 0)
                            const Text("(클릭하면 상세 오류 확인)",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
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
