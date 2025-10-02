import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Issue {
  final String wrongText;
  final String message;

  Issue(this.wrongText, this.message);
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final TextEditingController _meanCtrl = TextEditingController();
  final TextEditingController _compCtrl = TextEditingController();

  List<dynamic> _wordList = [];
  int _currentIndex = 0;
  Map<String, dynamic>? _cur;

  @override
  void initState() {
    super.initState();
    _fetchTodayWords();
  }

  Future<void> _fetchTodayWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final userId = prefs.getString('user_id');

      print('Token: $token');
      print('UserId: $userId');

      if (userId == null || token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없습니다.')),
        );
        return;
      }

      final url =
          Uri.parse('http://localhost:8080/api/v1/words/review/today/$userId');

      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _wordList = data['words'] ?? [];
          _currentIndex = 0;
          _cur = _wordList.isNotEmpty ? _wordList[0] : null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 조회 실패: ${res.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오늘 복습 단어 조회 예외: $e')),
      );
    }
  }

  void _nextQuiz() {
    if (_currentIndex + 1 < _wordList.length) {
      setState(() {
        _currentIndex++;
        _cur = _wordList[_currentIndex];
        _meanCtrl.clear();
        _compCtrl.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘 복습이 완료되었습니다! 🎉')),
      );
      setState(() {
        _cur = null;
      });
    }
  }

  bool _isMeaningCorrect() {
    if (_cur == null) return false;

    final userMeaning = _meanCtrl.text.trim().toLowerCase();
    final meaningStr = _cur?['meaning'] ?? '';
    final correctMeanings =
        meaningStr.split(',').map((e) => e.trim().toLowerCase()).toList();

    return correctMeanings.contains(userMeaning);
  }

  List<Issue> _validateComposition(String comp, String word) {
    if (!comp.contains(word)) {
      return [Issue(word, '문장에 단어가 포함되어 있지 않음')];
    }
    return [];
  }

  Future<List<Issue>> checkGrammar(String sentence) async {
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
          "session_id": "quiz_session_1",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final edits = data["edits"] as List;

        return edits.map<Issue>((e) {
          final wrongText = sentence.substring(
            e["start"] as int,
            (e["end"] as int).clamp(0, sentence.length),
          );
          final replacement = (e["replacements"] as List?)?.isNotEmpty == true
              ? e["replacements"][0]
              : "Error";

          return Issue(wrongText, replacement);
        }).toList();
      } else {
        return [Issue('', "문법 검사 실패: ${response.statusCode}")];
      }
    } catch (e) {
      return [Issue('', "문법 검사 오류: $e")];
    }
  }

  Future<void> _confirmQuiz() async {
    if (_cur == null) return;

    final mean = _meanCtrl.text.trim();
    if (mean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('뜻을 먼저 입력하세요.')),
      );
      return;
    }

    final isCorrect = _isMeaningCorrect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(isCorrect ? '정답! 🎉' : '오답 😅 정답: ${_cur?['meaning'] ?? ""}'),
      ),
    );

    // 서버에 기록
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final url = Uri.parse('http://localhost:8080/api/v1/words/quiz/record');
      final body = jsonEncode({
        'personalWordbookId': _cur?['personalWordbookId'],
        'wordId': _cur?['wordId'],
        'isWrong': !isCorrect,
      });

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        print('퀴즈 기록 저장 성공');
      } else {
        print('퀴즈 기록 저장 실패: ${res.statusCode}, ${res.body}');
      }
    } catch (e) {
      print('퀴즈 기록 예외: $e');
    }

    // 영작 검사
    final comp = _compCtrl.text.trim();
    if (comp.isNotEmpty) {
      final issues = _validateComposition(_compCtrl.text, _cur?['word'] ?? '');
      final grammarIssues = await checkGrammar(comp);
      final allIssues = [...issues, ...grammarIssues];

      if (allIssues.isNotEmpty) {
        await showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '문법 오류가 있습니다.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...allIssues
                    .map((d) => Text("틀린 부분: '${d.wrongText}' → ${d.message}"))
                    .toList(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    _nextQuiz();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(title: const Text('오늘의 복습')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _cur == null
            ? const Center(child: Text('복습할 단어가 없습니다!'))
            : Column(
                children: [
                  Text(
                    '단어: ${_cur?['word'] ?? ""}',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _meanCtrl,
                    decoration: const InputDecoration(
                      labelText: '뜻 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _compCtrl,
                    decoration: const InputDecoration(
                      labelText: '영작 입력 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _confirmQuiz,
                    child: const Text('확인'),
                  ),
                ],
              ),
      ),
    );
  }
}
