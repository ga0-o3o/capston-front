import 'package:flutter/material.dart';
import 'review_api.dart';
import 'review_loading.dart';
import '../word/word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../word/word_api.dart';

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

  Future<bool> _checkMeaningFromServer(String word, String userInput) async {
    try {
      final meanings = await WordApi.checkQuiz(word);

      final normalizedUser = userInput.trim().toLowerCase();
      final normalizedCorrect = meanings.map((e) => e.toLowerCase()).toList();

      return normalizedCorrect.contains(normalizedUser);
    } catch (e) {
      print("❌ 정답 확인 오류: $e");
      return false;
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

    // -------------------------------
    // 🔥 1) 서버에서 정답 뜻 가져와 비교
    // -------------------------------
    final isCorrect = await _checkMeaningFromServer(_cur!.word, mean);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect ? '정답! 🎉' : '오답 😅 정답: ${_cur!.wordKr.join(', ')}',
        ),
      ),
    );

    // 🔥 복습일 업데이트
    try {
      if (_cur != null &&
          _cur!.groupWordIds != null &&
          _cur!.groupWordIds!.isNotEmpty) {
        final updated = await ReviewApi.updateReviewDate(
            _cur!.personalWordbookId, _cur!.groupWordIds!.first);

        print(updated ? '복습일 업데이트 성공' : '복습일 업데이트 실패');
      }
    } catch (e) {
      print('복습일 업데이트 예외: $e');
    }

    // -------------------------------
    // 🔥 2) 영작 검사
    // -------------------------------
    final comp = _compCtrl.text.trim();

    if (comp.isNotEmpty) {
      final compositionIssues = _validateComposition(comp, _cur!.word);

      if (comp.split(RegExp(r'\s+')).length < 4) {
        compositionIssues.add(Issue(comp, '작문은 최소 4단어 이상이어야 합니다.'));
      }

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
                const Text('문법 오류가 있습니다.',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...allIssues.map(
                  (d) => Text("틀린 부분: '${d.wrongText}' → ${d.message}"),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _nextQuiz();
                    },
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    }

    // -------------------------------
    // 🔥 3) 문제 넘어가기
    // -------------------------------
    _nextQuiz();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 로딩 상태면 review_loading.dart의 로딩 화면 표시
    if (_loading) {
      return const LoadingPage();
    }

    return WillPopScope(
      onWillPop: () async {
        if (_cur == null) return true; // 복습 중이 아닐 땐 바로 나감

        // 다이얼로그 표시
        final shouldExit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/tear_cat1.png',
                  width: 450,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  '정말로 복습을 종료하시겠습니까?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFCC8C8),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(100, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text('종료하기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E6E99),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text('계속하기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        // true면 종료, false면 계속
        return shouldExit ?? false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F0E9),
        appBar: AppBar(
          title: const Text(
            '오늘의 복습',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF3D4C63),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _cur == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/No_review.png',
                        width: 450,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '복습할 단어가 없습니다!',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          _cur!.word,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
                        hintText:
                            '예) I can easily use this word in a sentence.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E6E99),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
      ),
    );
  }
}
