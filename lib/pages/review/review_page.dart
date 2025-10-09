import 'package:flutter/material.dart';
import 'review_api.dart';
import 'review_loading.dart';
import '../word/word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  List<WordItem> _wordList = [];
  int _currentIndex = 0;
  WordItem? _cur;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchTodayWords(showLoading: true);
  }

  Future<void> _fetchTodayWords({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final loginId = prefs.getString('user_id') ?? '';

      if (loginId.isEmpty) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없습니다.')),
        );
        return;
      }

      final words = await ReviewApi.fetchReviewWords(loginId);
      for (var w in words) {
        print(
            'word: ${w.word}, personalWordbookId: ${w.personalWordbookId}, groupWordIds: ${w.groupWordIds}');
      }

      if (!mounted) return;

      setState(() {
        _wordList = words;
        _currentIndex = 0;
        _cur = _wordList.isNotEmpty ? _wordList[0] : null;
        if (showLoading) _loading = false;
      });
    } catch (e) {
      print('❌ 단어 조회 에러: $e');
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어 조회 실패')),
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
    final correctMeanings = _cur!.wordKr.map((e) => e.toLowerCase()).toList();
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
        body: jsonEncode({"text": sentence, "session_id": "quiz_session_1"}),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('뜻을 먼저 입력하세요.')));
      return;
    }

    final isCorrect = _isMeaningCorrect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(isCorrect ? '정답! 🎉' : '오답 😅 정답: ${_cur!.wordKr.join(', ')}'),
      ),
    );

    // ✅ 복습일 업데이트
    try {
      if (_cur != null &&
          _cur!.groupWordIds != null &&
          _cur!.groupWordIds!.isNotEmpty) {
        final updated = await ReviewApi.updateReviewDate(
            _cur!.personalWordbookId, _cur!.groupWordIds!.first);

        if (updated) {
          print('복습일 업데이트 성공: ${_cur!.word}');
        } else {
          print('복습일 업데이트 실패: ${_cur!.word}');
        }
      }
    } catch (e) {
      print('복습일 업데이트 예외: $e');
    }

    // ✅ 영작 검사
    final comp = _compCtrl.text.trim();
    if (comp.isNotEmpty) {
      // 단어 포함 체크
      final compositionIssues = _validateComposition(comp, _cur!.word);

      // 4단어 이상 체크
      if (comp.split(RegExp(r'\s+')).length < 4) {
        compositionIssues.add(Issue(comp, '작문은 최소 4단어 이상이어야 합니다.'));
      }

      // 문법 체크
      final grammarIssues = await checkGrammar(comp);

      final allIssues = [...compositionIssues, ...grammarIssues];

      if (allIssues.isNotEmpty) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
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
                    onPressed: () {
                      Navigator.pop(context);
                      // 모달 닫은 후에 다음 문제
                      _nextQuiz();
                    },
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
        return; // 모달이 있으면 여기서 return, 다음 문제는 모달 닫을 때 진행
      }
    }

    // ✅ 영작이 없거나 오류 없으면 바로 다음 문제
    _nextQuiz();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 로딩 상태면 review_loading.dart의 로딩 화면 표시
    if (_loading) {
      return const LoadingPage(); // 여기서 LoadingPage는 review_loading.dart에서 import
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
          title: const Text(
            '오늘의 복습',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF3D4C63)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _cur == null
            ? const Center(
                child: Text('복습할 단어가 없습니다!',
                    style: TextStyle(fontSize: 16, color: Colors.black54)))
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(_cur!.word,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 56, fontWeight: FontWeight.w800)),
                    ),
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
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '작문 (선택: 단어 포함, 4단어↑ 권장)',
                      hintText: '예) I can easily use this word in a sentence.',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, // 화면 가로 꽉 채움
                    height: 60, // 높이 60으로 지정
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4E6E99),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16), // 내부 여백
                      ),
                      onPressed: _confirmQuiz,
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
