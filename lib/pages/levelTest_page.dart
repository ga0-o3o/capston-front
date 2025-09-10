import 'dart:convert';
import 'dart:math';
import 'login_page.dart';
import 'loading_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LevelTestPage extends StatefulWidget {
  const LevelTestPage({Key? key}) : super(key: key);

  @override
  State<LevelTestPage> createState() => _LevelTestPageState();
}

class _LevelTestPageState extends State<LevelTestPage> {
  List<Map<String, dynamic>> _words = [];
  int _currentIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  int _correctCount = 0;
  String? _feedback;

  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  int _currentLevelIndex = 0;
  final int _perLevelCount = 20;

  bool _isLoading = false;
  bool _levelSelected = false;

  // 레벨 선택 시 호출
  void _selectLevel(int index) {
    setState(() {
      _currentLevelIndex = index;
      _levelSelected = true;
      _isLoading = true;
    });
    _fetchLevelWords(_levels[index]);
  }

  // 해당 레벨 단어 불러오기
  Future<void> _fetchLevelWords(String level) async {
    setState(() {
      _isLoading = true;
      _feedback = null;
    });

    try {
      // SharedPreferences에서 저장된 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() {
          _feedback = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:8080/api/v1/wordbook?level=$level'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        List<Map<String, dynamic>> levelWords = List<Map<String, dynamic>>.from(
          data,
        );
        levelWords.shuffle();

        setState(() {
          _words = levelWords.take(_perLevelCount).toList();
          _currentIndex = 0;
          _correctCount = 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _feedback = '단어 불러오기 실패: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _feedback = '네트워크 오류: $e';
        _isLoading = false;
      });
    }
  }

  void _checkAnswer() {
    final correctMeaning = _words[_currentIndex]['koreanMeaning'];
    if (_answerController.text.trim() == correctMeaning) {
      _correctCount++;
      _feedback = '정답!';
    } else {
      _feedback = '틀렸습니다. 정답: $correctMeaning';
    }

    _answerController.clear();

    if (_currentIndex < _words.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _finishLevel();
    }
  }

  void _finishLevel() async {
    setState(() => _isLoading = true); // 1️⃣ 로딩 시작
    await Future.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token'); // 서버 JWT
    final userId = prefs.getString('user_id');

    int totalQuestions = _words.length;
    double scorePercent = (_correctCount / totalQuestions) * 100;

    String resultMessage =
        scorePercent >= 90
            ? '${scorePercent.toStringAsFixed(1)}점으로 통과!'
            : '${scorePercent.toStringAsFixed(1)}점으로 미통과';

    bool canNextLevel =
        scorePercent >= 90 && _currentLevelIndex < _levels.length - 1;

    print('---- 레벨 테스트 종료 ----');
    print('scorePercent: $scorePercent');

    if (scorePercent >= 90 && token != null) {
      final newRank = _levels[_currentLevelIndex];
      final uri = Uri.parse("http://localhost:8080/api/user/update-rank");

      print("📝 POST 요청 준비: userId=$userId, newRank=$newRank");

      try {
        final response = await http.post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token", // 로그인 시 받은 토큰 사용
          },
          body: jsonEncode({"id": userId, "userRank": newRank}),
        );

        print('PUT 요청 상태 코드: ${response.statusCode}');
        if (response.statusCode == 200) {
          await prefs.setString('user_rank', newRank);
          print("✅ 랭크 업데이트 성공: $newRank");
        } else if (response.statusCode == 403) {
          print("❌ 권한 거부 403 - 서버에서 JWT 검증 실패 가능");
        } else {
          print("❌ PUT 요청 실패: ${response.statusCode}");
        }
      } catch (e) {
        print("⚠️ 랭크 업데이트 중 오류: $e");
      }
    } else if (token == null) {
      print("❌ 토큰 없음, 로그인 필요");
    }

    setState(() => _isLoading = false);

    // 결과 다이얼로그
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFFE8E0FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              canNextLevel ? '레벨 통과!' : '레벨 테스트 종료',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              '이번 단계 맞춘 개수: $_correctCount / $totalQuestions\n'
              '점수: ${scorePercent.toStringAsFixed(1)}%\n'
              '$resultMessage',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _levelSelected = false);
                  },
                  child: const Text('확인', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 레벨 선택 화면
    if (!_levelSelected) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F0E9), // 배경 색상
        appBar: AppBar(
          title: const Text('레벨 선택'),
          backgroundColor: const Color(0xFF4E6E99), // AppBar 색상
        ),
        body: GridView.count(
          crossAxisCount: 3,
          padding: const EdgeInsets.all(16),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: List.generate(_levels.length, (index) {
            return GestureDetector(
              onTap: () => _selectLevel(index),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 버튼 배경 이미지
                  Image.asset(
                    'assets/images/button.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                  // 버튼 위 텍스트
                  Text(
                    _levels[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          blurRadius: 3,
                          color: Colors.black,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      );
    }

    // 문제 화면 build()에서
    if (_isLoading) {
      return const LoadingPage(); // CircularProgressIndicator 대신 LoadingPage 사용
    }

    if (_words.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            _feedback ?? '단어가 없습니다.',
            style: const TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    // 문제 화면
    final word = _words[_currentIndex];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9), // 배경 색상
      appBar: AppBar(
        title: Text('레벨: ${_levels[_currentLevelIndex]}'),
        backgroundColor: const Color(0xFF4E6E99), // AppBar 색상
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('문제 ${_currentIndex + 1} / ${_words.length}'),
            const SizedBox(height: 16),
            Text(
              word['wordEn'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: '뜻 입력',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40), // 버튼 위 간격 충분히 띄움
            SizedBox(
              width: double.infinity, // 버튼 가로 폭 전체
              height: 50, // 버튼 높이
              child: ElevatedButton(
                onPressed: _checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99), // 파스텔 톤 파랑
                  foregroundColor: Colors.white, // 글자 색
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // 둥근 모서리
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 20, // 글자 크기
                    fontWeight: FontWeight.bold, // 글자 굵게
                  ),
                ),
              ),
            ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _feedback!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
