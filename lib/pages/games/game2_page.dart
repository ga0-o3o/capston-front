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

  /// ✅ 문법 검사: 오류 메시지, 틀린 단어 추출
  Future<List<Map<String, String>>> checkGrammar(String sentence) async {
    final url = Uri.parse("https://api.languagetoolplus.com/v2/check");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body:
            "text=${Uri.encodeComponent(sentence.replaceAll('\n', ' '))}&language=en-US",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data["matches"] as List;

        // 문법 오류 상세 정보 (메시지 + 틀린 부분)
        return matches.map<Map<String, String>>((m) {
          final offset = m["offset"] as int;
          final length = m["length"] as int;
          final wrong = sentence.substring(
              offset, (offset + length).clamp(0, sentence.length));
          return {
            "message": m["message"],
            "wrongText": wrong,
          };
        }).toList();
      } else {
        print(
            "LanguageTool API error: ${response.statusCode} ${response.body}");
        return [];
      }
    } catch (e) {
      print("LanguageTool API exception: $e");
      return [];
    }
  }

  void checkAnswer() async {
    if (currentWord == null || gameOver) return;

    final answer = currentWord!["wordEn"].toString();
    final meaning = currentWord!["koreanMeaning"].toString();
    final submitted = controller.text.trim();

    // 제시어 포함 여부 먼저 확인
    if (!submitted.toLowerCase().contains(answer.toLowerCase())) {
      lives--;
      if (lives <= 0) {
        _endGame();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("틀렸습니다! 제시어가 포함되어 있지 않습니다. 목숨 -1")),
        );
      }
      controller.clear();
      setState(() {});
      return;
    }

    // ✅ 문법 검사 (상세정보 포함)
    final grammarDetails = await checkGrammar(submitted);

    submittedAnswers.insert(0, {
      "word": answer,
      "meaning": meaning,
      "submitted": submitted,
      "grammarErrors": grammarDetails.length,
      "grammarDetails": grammarDetails, // 리스트 그대로 저장
    });

    if (grammarDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("정답! 문법도 OK")),
      );
      _nextQuestion();
    } else {
      lives--;
      if (lives <= 0) {
        _endGame();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("문법 오류 ${grammarDetails.length}개 발견! 목숨 -1"),
          ),
        );
      }
    }

    controller.clear();
    setState(() {});
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
            "게임이 종료되었습니다!\n남은 목숨: $lives\n총 제출한 답: ${submittedAnswers.length}개"),
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
        title: const Text("제시어 영작 게임"),
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
