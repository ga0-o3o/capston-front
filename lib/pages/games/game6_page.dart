import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Game6Page extends StatefulWidget {
  const Game6Page({Key? key}) : super(key: key);

  @override
  State<Game6Page> createState() => _Game6PageState();
}

class _Game6PageState extends State<Game6Page> {
  String mode = ""; // "", "solo", "multi"
  List<Map<String, dynamic>> words = [];
  int currentWordIndex = 0;
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchWords("A1"); // 테스트: A1 레벨 단어 불러오기
  }

  Future<void> fetchWords(String level) async {
    final url = Uri.parse("http://localhost:8080/api/v1/wordbook?level=$level");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        words = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }

  void checkAnswer() {
    if (controller.text.trim().toLowerCase() ==
        words[currentWordIndex]["wordEn"].toString().toLowerCase()) {
      // 정답 → 블록 쌓기 로직 호출
      print("정답! 블록 추가");
      setState(() {
        currentWordIndex = (currentWordIndex + 1) % words.length;
      });
    } else {
      print("오답!");
    }
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (mode == "") {
      // 선택 화면
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF4E6E99),
          title: const Text("게임 6 - 단어 타워"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => mode = "solo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // 녹색 버튼
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ), // 버튼 크기 키우기
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20), // 모서리 둥글게
                      ),
                    ),
                    child: const Text(
                      "혼자",
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16), // 버튼 사이 간격
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => mode = "multi"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "같이",
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 게임 화면
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: Text(mode == "solo" ? "솔로 모드" : "배틀 모드"),
      ),
      body: Column(
        children: [
          // 흰 네모에 단어 표시
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            height: 80,
            width: double.infinity,
            color: Colors.white,
            child: Center(
              child: Text(
                words.isNotEmpty
                    ? words[currentWordIndex]["koreanMeaning"] ?? "단어 없음"
                    : "로딩 중...",
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          // Flame Game 영역 (타워 쌓기)
          Expanded(child: GameWidget(game: Game6())),
          // 입력창
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "정답 입력",
              ),
              onSubmitted: (_) => checkAnswer(),
            ),
          ),
        ],
      ),
    );
  }
}

class Game6 extends FlameGame {
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // 타워 초기화
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 블록 위치 업데이트
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // 블록(타워) 그리기
  }
}
