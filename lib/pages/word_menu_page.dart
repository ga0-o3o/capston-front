import 'dart:math';
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../models/word_item.dart';
import '../models/definition_item.dart';
import '../services/django_api.dart';
import '../widgets/review_words_sheet.dart';
import '../widgets/review_meanings_sheet.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WordMenuPage extends StatefulWidget {
  final int? wordbookId;

  const WordMenuPage({Key? key, this.wordbookId}) : super(key: key);

  @override
  State<WordMenuPage> createState() => _WordMenuPageState();
}

class WordItem {
  final int personalWordbookWordId; // 고유 ID
  final int personalWordbookId;
  String word; // 영단어
  String wordKr; // 한글 뜻 (백엔드와 일치)
  String meaning; // 뜻 (현재 코드에서는 wordKr과 동일하게 사용)
  bool favorite;

  WordItem({
    required this.personalWordbookWordId,
    required this.personalWordbookId,
    required this.word,
    required this.wordKr,
    required this.meaning,
    this.favorite = false,
  });
}

class Issue {
  final String wrongText; // 틀린 부분
  final String message; // 추천 수정 또는 설명

  Issue(this.wrongText, this.message);
}

class _WordMenuPageState extends State<WordMenuPage> {
  List<WordItem> _items = [];
  Map<String, int> _hsvValues = {'h': 120, 's': 255, 'v': 255};

  String _searchQuery = '';
  final _searchController = TextEditingController();

  final _imagePicker = ImagePicker();
  bool _uploading = false;

  final _rnd = Random();
  final _meanCtrl = TextEditingController();
  final _compCtrl = TextEditingController();
  final _meanFocus = FocusNode();
  late WordItem _cur;

  @override
  void initState() {
    super.initState();
    if (widget.wordbookId != null) _fetchWords();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _meanCtrl.dispose();
    _compCtrl.dispose();
    _meanFocus.dispose();
    super.dispose();
  }

  void _nextQuiz() {
    if (_items.isEmpty) return;
    _cur = _items[_rnd.nextInt(_items.length)];
    _meanCtrl.clear();
    _compCtrl.clear();
    setState(() {});
    Future.delayed(
        const Duration(milliseconds: 30), () => _meanFocus.requestFocus());
  }

  Future<void> _mergeWords(WordItem source, WordItem target) async {
    if (source.word.toLowerCase() != target.word.toLowerCase()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('단어가 달라 병합할 수 없습니다.')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = Uri.parse('http://localhost:8080/api/v1/words/merge');
    final body = jsonEncode({
      'personalWordbookWordIds': [
        source.personalWordbookWordId,
        target.personalWordbookWordId
      ]
    });

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // 서버에서 새로 생성된 단어 ID와 병합된 의미를 가져옴
        final mergedId = data['mergedId'] ?? target.personalWordbookWordId;
        final mergedMeaning =
            data['mergedMeaning'] ?? '${target.meaning}, ${source.meaning}';

        // 로컬 상태 갱신
        setState(() {
          // 기존 source, target 삭제
          _items.removeWhere((e) =>
              e.personalWordbookWordId == source.personalWordbookWordId ||
              e.personalWordbookWordId == target.personalWordbookWordId);

          // 새 WordItem 생성 후 삽입
          _items.insert(
            0,
            WordItem(
              personalWordbookWordId: mergedId,
              personalWordbookId: target.personalWordbookId,
              word: target.word,
              wordKr: mergedMeaning,
              meaning: mergedMeaning,
              favorite: target.favorite,
            ),
          );
        });
        await _fetchWords();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${source.word}" 카드가 합쳐졌습니다.')));
      } else {
        final msg = (jsonDecode(res.body)['message'] ?? '병합 실패');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $msg')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    }
  }

  bool _isMeaningCorrect() {
    final userMeaning = _meanCtrl.text.trim().toLowerCase();
    // 정답 뜻을 쉼표(,) 기준으로 분리하여 각각 비교
    final correctMeanings =
        _cur.meaning.split(',').map((e) => e.trim().toLowerCase()).toList();

    // 입력된 뜻이 정답 뜻 목록 중 하나라도 포함되는지 확인
    return correctMeanings.contains(userMeaning);
  }

  List<Issue> _validateComposition(String s, String target) {
    final t = s.trim();
    final out = <Issue>[];
    if (t.isEmpty) return out;
    if (!t.toLowerCase().contains(target.toLowerCase())) {
      out.add(Issue(target, '문장에 "$target" 단어가 포함되어야 해요.'));
    }
    if (t.split(RegExp(r'\s+')).length < 4) {
      out.add(Issue('', '문장은 4단어 이상으로 작성해 주세요.'));
    }
    if (!RegExp(r'[.!?]$').hasMatch(t)) {
      out.add(Issue('', '문장 끝에 마침표/물음표를 붙이면 더 좋아요.'));
    }
    return out;
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

          return Issue(wrongText, replacement); // ✅ Issue 객체 생성
        }).toList();
      } else {
        return [Issue('', "문법 검사 실패: ${response.statusCode}")];
      }
    } catch (e) {
      return [Issue('', "문법 검사 오류: $e")];
    }
  }

  Future<void> _fetchWords() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = Uri.parse(
        'http://localhost:8080/api/v1/words/wordbook/${widget.wordbookId}');

    try {
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      print(res.body);

      if (res.statusCode == 200) {
        print("성공");
        final data = jsonDecode(res.body);
        // 서버 응답 구조에 맞게 변환
        final words = (data['words'] as List).map((w) {
          // null 체크 후 기본값 설정
          final wordId = w['personalWordbookWordId'] ?? 0;
          final wordbookId = w['personalWordbookId'] ?? 0;

          return WordItem(
            personalWordbookWordId: wordId,
            personalWordbookId: wordbookId,
            word: w['wordEn'] ?? '',
            wordKr: w['wordKr'] ?? '',
            meaning: w['meaning'] ?? '',
            favorite: w['favorite'] ?? false,
          );
        }).toList();

        setState(() => _items = words);

        _items.forEach((item) {
          print('Word: ${item.word}, WordbookId: ${item.personalWordbookId}');
        });

        if (_items.isNotEmpty) _nextQuiz();
      } else if (res.statusCode == 400 || res.statusCode == 404) {
        final msg = jsonDecode(res.body)['message'] ?? '단어장 조회 실패';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('서버 오류')));
      }
    } catch (e) {
      print('❌ [FETCH WORDS] 네트워크 오류2 발생: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    }
  }

  Future<int?> _addWordToServer({
    required String wordEn,
    required String wordKr,
    required String meaning,
    int? personalWordbookId,
  }) async {
    print('1. _addWordToServer 호출됨');

    final url = Uri.parse('http://localhost:8080/api/v1/words');
    print('2. URL 준비 완료: $url');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    print('3. JWT 토큰 가져옴: $token');

    // personalWordbookId가 null이면 1로 기본값 설정
    final bodyMap = {
      'wordEn': wordEn,
      'wordKr': wordKr,
      'meaning': meaning,
      'personalWordbookId': personalWordbookId ?? 1,
    };
    final body = jsonEncode(bodyMap);
    print('4. 요청 바디 준비 완료: $body');

    try {
      print('5. POST 요청 전송...');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      print('6. 서버 응답 받음, 상태 코드: ${res.statusCode}');
      print('7. 서버 응답 바디: ${res.body}');

      final responseData = jsonDecode(res.body);

      if (res.statusCode == 200) {
        // 서버가 반환한 ID가 없을 경우 null 처리
        final newId = responseData['personalWordbookWordId'] as int?;
        print('8. 새로 생성된 ID 반환: $newId');

        await _fetchWords(); // 서버 반영 후 전체 리스트 갱신
        print('9. 단어 리스트 갱신 완료');

        return newId;
      } else {
        // 서버 에러 메시지 처리
        final msg = responseData['message'] ?? '서버 오류';
        print('10. 서버 오류 발생: $msg');

        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
        return null;
      }
    } catch (e) {
      print('11. 네트워크 오류 발생: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      }
      return null;
    }
  }

  Future<void> _showEditMenu(WordItem it) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수정'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog(WordItem it) async {
    final newWordCtrl = TextEditingController(text: it.word);
    List<String> meaningCandidates = [];
    List<String> selectedMeanings = [];

    // 1단계: 단어 검색 & 뜻 후보 가져오기
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('단어 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 새 단어 입력창
              TextField(
                controller: newWordCtrl,
                decoration: InputDecoration(
                  labelText: '새 단어 입력',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final newWord = newWordCtrl.text.trim();
                      if (newWord.isEmpty) return;

                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('jwt_token') ?? '';
                        final loginId = prefs.getString('login_id') ?? '';

                        final url = Uri.parse(
                            'http://localhost:8080/api/v1/words/search-for-update');
                        final body = jsonEncode({
                          'loginId': loginId,
                          'personalWordbookId': it.personalWordbookId,
                          'wordId': it.personalWordbookWordId,
                          'newWord': newWord,
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
                          final data = jsonDecode(res.body);
                          setState(() {
                            meaningCandidates =
                                List<String>.from(data['meanings']);
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('검색 실패: ${res.body}')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('검색 오류: $e')),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 뜻 후보 표시
              if (meaningCandidates.isNotEmpty) ...[
                const Text(
                  "검색된 뜻 선택:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: meaningCandidates.map((m) {
                    final isSelected = selectedMeanings.contains(m);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedMeanings.remove(m);
                          } else {
                            selectedMeanings.add(m);
                          }
                        });
                      },
                      child: Chip(
                        label: Text(m),
                        backgroundColor: isSelected
                            ? Colors.green.shade200
                            : Colors.blue.shade100,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                if (newWordCtrl.text.trim().isEmpty || selectedMeanings.isEmpty)
                  return;

                // 2단계: 선택된 뜻으로 최종 업데이트
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('jwt_token') ?? '';
                  final loginId = prefs.getString('login_id') ?? '';

                  final url = Uri.parse(
                      'http://localhost:8080/api/v1/words/confirm-update');

                  // 여러 뜻 선택 가능 → 서버가 하나만 받을 경우 첫 번째만 사용
                  final newWordKr =
                      selectedMeanings.join(", "); // 혹은 선택 정책에 맞게 변경

                  final body = jsonEncode({
                    'loginId': loginId,
                    'personalWordbookId': it.personalWordbookId,
                    'personalWordbookWordId': it.personalWordbookWordId,
                    'newWordEn': newWordCtrl.text.trim(),
                    'newWordKr': newWordKr,
                  });

                  final res = await http.put(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: body,
                  );

                  if (res.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('단어 수정 완료')),
                    );
                    await _fetchWords(); // 단어 목록 갱신
                    Navigator.pop(ctx);
                  } else {
                    final msg = jsonDecode(res.body)['message'] ?? '수정 실패';
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('서버 오류: $e')));
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

/*   Future<bool> _updateWordOnServer({
    required int personalWordbookWordId,
    required String wordEn,
    required String wordKr,
    required String meaning,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = Uri.parse('http://localhost:8080/api/v1/words');

    final body = jsonEncode({
      'personalWordbookWordId': personalWordbookWordId,
      'wordEn': wordEn,
      'wordKr': wordKr,
      'meaning': meaning,
    });

    try {
      final res = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        return true;
      } else {
        final msg = jsonDecode(res.body)['message'] ?? '수정 실패';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $msg')));
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      return false;
    }
  } */

  Future<void> _confirmQuiz() async {
    final mean = _meanCtrl.text.trim();
    if (mean.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('뜻을 먼저 입력하세요.')));
      return;
    }
    if (_cur == null) return;

    // 뜻 검사 (중복 호출 제거)
    final isCorrect = _isMeaningCorrect();
    if (!isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오답 😅  정답: ${_cur.meaning}')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('정답! 🎉')));
    }

    // 서버에 퀴즈 기록 저장
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse('http://localhost:8080/api/v1/words/quiz/record');

      // 여기서 `isCorrect` 변수를 재사용
      final isWrong = !isCorrect;

      final body = jsonEncode({
        'personalWordbookId': _cur.personalWordbookId,
        'personalWordbookWordId': _cur.personalWordbookWordId,
        'isWrong': isWrong,
      });

      print('퀴즈 기록 전송 body: $body');

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
        print(res.body);
      } else {
        print('퀴즈 기록 저장 실패: ${res.statusCode}, ${res.body}');
      }
    } catch (e) {
      print('퀴즈 기록 예외: $e');
    }

    // 영작 검사
    final comp = _compCtrl.text.trim();
    if (comp.isNotEmpty) {
      final issues = _validateComposition(comp, _cur.word);
      final grammarIssues = await checkGrammar(comp);
      final allIssues = [...issues, ...grammarIssues];

      if (allIssues.isNotEmpty) {
        // 문법 오류 보여주고 닫은 후 다음 문제
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

    // ✅ 문법 오류 체크 후 다음 문제 진행
    _nextQuiz();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F0E9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F0E9),
          elevation: 0,
          title: const Text('단어장', style: TextStyle(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: const TabBar(
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.black45,
            indicatorColor: Color(0xFF4E6E99),
            tabs: [Tab(text: '내 단어'), Tab(text: '즐겨찾기'), Tab(text: '퀴즈')],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildListView(_items),
                _buildListView(_items.where((e) => e.favorite).toList()),
                _buildQuizTab(_items),
              ],
            ),
            if (_uploading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.15),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF4E6E99),
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: _openAddMenu, // 수동 추가/이미지 추가 선택
        ),
      ),
    );
  }

  Future<void> _openAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('직접 추가 (영단어/뜻 입력)'),
            onTap: () => Navigator.pop(context, 'manual'),
          ),
          ListTile(
            leading: const Icon(Icons.image_search),
            title: const Text('이미지로 추가 (형광펜 인식)'),
            onTap: () => Navigator.pop(context, 'image'),
          ),
        ]),
      ),
    );

    if (choice == 'manual') {
      await _openAddDialog();
    } else if (choice == 'image') {
      await _openImageSourceSheet();
    }
  }

  Future<void> _openAddDialog() async {
    final _meanCtrl = TextEditingController();
    List<Map<String, dynamic>> meaningCandidates = []; // 서버에서 받은 뜻과 ID
    List<Map<String, dynamic>> selectedMeanings = []; // 선택한 뜻 저장

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("단어 추가"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 영어 단어 입력창 + 검색 버튼
                TextField(
                  controller: _meanCtrl,
                  decoration: InputDecoration(
                    labelText: "영단어 입력",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final word = _meanCtrl.text.trim();
                        if (word.isEmpty) return;

                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString("jwt_token") ?? "";

                          final url = Uri.parse(
                            "http://localhost:8080/api/v1/words/dictionary-search?wordEn=$word",
                          );

                          final res = await http.get(
                            url,
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                          );

                          if (res.statusCode == 200) {
                            final data = jsonDecode(res.body);
                            setState(() {
                              // 서버에서 {id, meaning} 구조로 받는다고 가정
                              meaningCandidates =
                                  List<Map<String, dynamic>>.from(
                                      data['meanings']);
                              selectedMeanings = [];
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("검색 실패: ${res.body}")),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("예외 발생: $e")),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 검색된 한글 뜻들을 밑에 표시
                if (meaningCandidates.isNotEmpty) ...[
                  const Text(
                    "검색된 뜻:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: meaningCandidates.map((m) {
                      final isSelected = selectedMeanings.contains(m);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedMeanings.remove(m);
                            } else {
                              selectedMeanings.add(m);
                            }
                          });
                        },
                        child: Chip(
                          label: Text(m['meaning']),
                          backgroundColor: isSelected
                              ? Colors.green.shade300
                              : Colors.blue.shade100,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("닫기"),
              ),
              FilledButton(
                onPressed: selectedMeanings.isEmpty
                    ? null
                    : () async {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString("jwt_token") ?? "";

                        final url = Uri.parse(
                            "http://localhost:8080/api/v1/words/save-selected");

                        try {
                          final res = await http.post(
                            url,
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode({
                              "personalWordbookId": widget.wordbookId,
                              "wordIds":
                                  selectedMeanings.map((e) => e['id']).toList(),
                            }),
                          );

                          if (res.statusCode == 200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("선택된 단어가 저장되었습니다.")),
                            );
                            Navigator.pop(ctx);
                          } else {
                            final data = jsonDecode(res.body);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      "저장 실패: ${data['message'] ?? res.body}")),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("서버 오류 발생: $e")),
                          );
                        }
                      },
                child: const Text("저장"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openImageSourceSheet() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (kIsWeb || isDesktop) {
      final res = await FilePicker.platform.pickFiles(
          type: FileType.image, allowMultiple: false, withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.single;
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('이미지를 불러오지 못했습니다.')));
        return;
      }
      await _uploadFlow(bytes, f.name);
      return;
    }

    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;

    final x = await _imagePicker.pickImage(
        source: src, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _uploadFlow(bytes, x.name);
  }

  Future<void> _uploadFlow(Uint8List bytes, String filename) async {
    setState(() => _uploading = true);
    try {
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 크기가 너무 큽니다(최대 8MB).')));
        return;
      }

      // 1️⃣ 이미지에서 단어 추출
      final words = await DjangoApi.uploadAndExtract(
        bytes: bytes,
        filename: filename,
        h: _hsvValues['h']!,
        s: _hsvValues['s']!,
        v: _hsvValues['v']!,
      );

      if (words.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('인식된 단어가 없습니다.')));
        return;
      }

      // 2️⃣ 단어 확인/편집
      final edited = await showReviewWordsSheet(context, initialWords: words);
      if (edited == null || edited.isEmpty) return;

      // 3️⃣ 의미 정의
      List<DefinitionItem> defs;
      try {
        defs = await DjangoApi.defineWords(edited);
      } catch (_) {
        defs = edited
            .map((w) =>
                DefinitionItem(word: w, meaning: '', pos: '', example: ''))
            .toList();
      }

      final confirmed = await showReviewMeaningsSheet(context, defs: defs);
      if (confirmed == null || confirmed.isEmpty) return;

      // 4️⃣ 서버(DB) 저장 + 로컬 리스트 반영
      final exist = _items.map((e) => e.word.toLowerCase()).toSet();
      int addedCount = 0;

      for (final m in confirmed) {
        final w = (m['word'] ?? '').trim();
        final mean = (m['meaning'] ?? '').trim();
        if (w.isEmpty) continue;

        // 이미 없는 단어만 처리
        if (exist.add(w.toLowerCase())) {
          final serverWordId = await _addWordToServer(
            wordEn: w,
            wordKr: mean,
            meaning: mean,
            personalWordbookId: widget.wordbookId,
          );

          if (serverWordId != null) {
            setState(() {
              _items.insert(
                0,
                WordItem(
                  personalWordbookWordId: serverWordId,
                  personalWordbookId: widget.wordbookId!,
                  word: w,
                  wordKr: mean,
                  meaning: mean,
                ),
              );
            });
            addedCount++;
          }
        }
      }

      if (addedCount > 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('단어장에 $addedCount개 추가됨')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // === 여기부터 삭제(X 버튼) 관련 헬퍼 ===
  Future<void> _confirmDelete(WordItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('${it.word} - ${it.meaning}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );

    if (ok == true) {
      final success = await _deleteWordFromServer(it.personalWordbookWordId);
      if (success) _removeItemById(it.personalWordbookWordId);
    }
  }

  void _removeItemById(int personalWordbookWordId) {
    final idx = _items
        .indexWhere((e) => e.personalWordbookWordId == personalWordbookWordId);
    if (idx >= 0) setState(() => _items.removeAt(idx));
  }

  Future<bool> _deleteWordFromServer(int personalWordbookWordId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url =
        Uri.parse('http://localhost:8080/api/v1/words/$personalWordbookWordId');

    try {
      final res = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) return true;

      final msg = jsonDecode(res.body)['message'] ?? '삭제 실패';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $msg')));
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      return false;
    }
  }

  void _removeByWord(String word) {
    final idx =
        _items.indexWhere((e) => e.word.toLowerCase() == word.toLowerCase());
    if (idx >= 0) {
      setState(() => _items.removeAt(idx));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$word" 삭제됨')));
    }
  }
  // === 삭제 헬퍼 끝 ===

  /// 리스트(내 단어/즐겨찾기) — 카드 내부 우측 상단 X 버튼
  Widget _buildListView(List<WordItem> data) {
    final filtered = _searchQuery.isEmpty
        ? data
        : data
            .where((e) =>
                e.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.meaning.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '단어 검색',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text.trim();
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF4E6E99),
                  width: 2.0,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('검색 결과가 없습니다',
                      style: TextStyle(fontSize: 16, color: Colors.black54)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final it = filtered[i];

                    return LongPressDraggable<WordItem>(
                      data: it,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Card(
                          elevation: 4,
                          child: SizedBox(
                            width: 200,
                            child: ListTile(
                              title: Text(it.word),
                              subtitle: Text(it.meaning),
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: _buildCard(it), // 클릭 기능 유지
                      ),
                      // 여기서 DragTarget으로 감싸서 다른 카드 드래그 시 합치기
                      child: DragTarget<WordItem>(
                        onAccept: (dragged) => _mergeWords(dragged, it),
                        builder: (context, candidateData, rejectedData) {
                          return Stack(
                            children: [
                              _buildCard(it,
                                  highlight: candidateData.isNotEmpty),
                            ],
                          );
                        },
                      ),
                    );
                  }),
        ),
      ],
    );
  }

  Widget _buildDraggableCard(WordItem it) {
    return LongPressDraggable<WordItem>(
      data: it,
      feedback: Material(
        color: Colors.transparent,
        child: Card(
          elevation: 4,
          child: SizedBox(
            width: 200,
            child: ListTile(
              title: Text(it.word),
              subtitle: Text(it.meaning),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildCard(it),
      ),
      child: DragTarget<WordItem>(
        onAccept: (dragged) => _mergeWords(dragged, it),
        builder: (context, candidateData, rejectedData) {
          return _buildCard(it, highlight: candidateData.isNotEmpty);
        },
      ),
    );
  }

  Widget _buildCard(WordItem it, {bool highlight = false}) {
    return Card(
      color: highlight ? Colors.blue[50] : Colors.white,
      child: ListTile(
        title: Text(it.word),
        subtitle: Text(it.meaning),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 즐겨찾기 버튼
            IconButton(
              icon: Icon(
                it.favorite ? Icons.star : Icons.star_border,
                color: Colors.amber[700],
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('jwt_token') ?? '';
                final url = Uri.parse(
                    'http://localhost:8080/api/v1/words/favorite/${it.personalWordbookWordId}');

                print('📡 [FAVORITE] 요청 URL: $url');
                print('📡 [FAVORITE] JWT 토큰: $token');

                try {
                  final res = await http.put(
                    url,
                    headers: {
                      'Authorization': 'Bearer $token',
                    },
                  );

                  print('📡 [FAVORITE] 응답 코드: ${res.statusCode}');
                  print('📡 [FAVORITE] 응답 본문: ${res.body}');

                  if (res.statusCode == 200) {
                    // 서버는 message만 내려주니까, 직접 상태를 반전시킴
                    setState(() => it.favorite = !it.favorite);
                    print('✅ [FAVORITE] 즐겨찾기 상태 변경: ${it.favorite}');
                  } else {
                    print('❌ [FAVORITE] 상태 변경 실패 (status: ${res.statusCode})');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('즐겨찾기 상태 변경 실패: ${res.statusCode}')),
                    );
                  }
                } catch (e) {
                  print('❌ [FAVORITE] 네트워크 예외 발생: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('서버와 연결할 수 없습니다: $e')),
                  );
                }
              },
            ),
            // 휴지통 버튼
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFF4E6E99)),
              onPressed: () => _confirmDelete(it),
            ),
          ],
        ),
        onTap: () => _showEditMenu(it),
      ),
    );
  }

  Widget _buildQuizTab(List<WordItem> words) {
    if (words.isEmpty || _cur == null) {
      return const Center(
        child: Text('단어가 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Center(
            child: Text(_cur!.word, // null 체크 후 !
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 56, fontWeight: FontWeight.w800)),
          ),
        ),
        TextField(
          controller: _meanCtrl,
          focusNode: _meanFocus,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirmQuiz(),
          decoration: InputDecoration(
            labelText: '뜻(필수)',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _compCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '작문 (선택: 단어 포함, 4단어↑ 권장)',
            hintText: '예) I can easily use this word in a sentence.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E6E99),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _confirmQuiz,
            child: const Text('확인',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
