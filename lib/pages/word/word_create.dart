import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../fake_progress_bar.dart';
import 'word_meaning.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordCreatePage extends StatefulWidget {
  final int wordbookId;

  const WordCreatePage({Key? key, required this.wordbookId}) : super(key: key);

  @override
  State<WordCreatePage> createState() => _WordCreatePageState();
}

class _WordCreatePageState extends State<WordCreatePage> {
  final _wordController = TextEditingController();

  /// 사용자가 입력한 원문 목록
  List<String> _wordsToAdd = [];

  /// 표제어(교정된 영단어) -> 의미 목록
  Map<String, List<WordMeaning>> _wordsWithMeanings = {};

  /// 표제어 -> 선택한 한국어 뜻(문자열) 집합
  Map<String, Set<String>> _selectedMeaningIds = {};

  bool _loading = false;

  /// 원문(사용자 입력) -> 표제어(교정된 영단어)
  final Map<String, String> _origToCanonical = {};

  /// 표제어 -> 이 표제어를 만든 원문들
  final Map<String, Set<String>> _canonicalToOrigs = {};

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  /// 간단 정규화(선택): 소문자+양끝공백 제거
  String _normalize(String s) => s.toLowerCase().trim();

  void _addWordToList() {
    final raw = _wordController.text;
    final word = _normalize(raw);
    if (word.isEmpty) return;
    if (!_wordsToAdd.contains(word)) {
      setState(() => _wordsToAdd.add(word));
    }
    _wordController.clear();
  }

  Future<void> _fetchMeanings() async {
    if (_wordsToAdd.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    setState(() => _loading = true);

    final url = Uri.parse(
        'https://semiconical-shela-loftily.ngrok-free.dev/api/words/save-from-api');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'wordsEn': _wordsToAdd}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        // 서버가 배열 or {results: [...]} 둘 다 허용
        final List results = () {
          if (decoded is List) return decoded;
          if (decoded is Map && decoded['results'] is List) {
            return decoded['results'] as List;
          }
          throw const FormatException('Unexpected response shape');
        }();

        final Map<String, List<WordMeaning>> newMeanings = {};
        final Map<String, String> newOrig2Can = {};
        final Map<String, Set<String>> newCan2Origs = {};

        final List<String> canonicalKeys = [];
        final List<String> canonicalNorms = [];

        // 🔥 인덱스를 같이 돌면서 from 이 비어 있으면
        //    _wordsToAdd[i] 를 fallback 으로 사용
        for (int i = 0; i < results.length; i++) {
          final item = results[i];
          if (item is! Map) continue;

          final canonical =
              (item['wordEn'] ?? item['canonical'] ?? item['lemma'])
                  ?.toString()
                  .trim();
          if (canonical == null || canonical.isEmpty) continue;

          // 👇 canonical 목록에 저장
          final canonNorm = _normalize(canonical);
          canonicalKeys.add(canonical);
          canonicalNorms.add(canonNorm);

          // 1차: 서버가 내려준 original 필드 사용 (오타 보정일 때 들어온다고 가정)
          String? from =
              (item['originalQuery'] ?? item['original'])?.toString().trim();

          // ❌ 여기 있던 "i번째 단어 fallback" 은 삭제 (porple 케이스는 밑에서 따로 처리)

          // 의미 배열 후보
          final raw = item['wordMeanings'] ??
              item['meaningDetails'] ??
              item['meanings'];
          if (raw is! List) continue;

          final seenKr = <String>{};
          final list = <WordMeaning>[];
          for (final e in raw) {
            if (e is! Map) continue;
            final kr =
                (e['wordKr'] ?? e['meaning'] ?? e['ko'])?.toString().trim();
            if (kr == null || kr.isEmpty) continue;
            if (seenKr.add(kr)) {
              list.add(WordMeaning(
                wordId: e['wordId'] ?? e['id'] ?? e['meaningId'],
                wordKr: kr,
              ));
            }
          }
          if (list.isEmpty) continue;

          // 표제어 기준으로 의미 누적
          newMeanings.update(canonical, (prev) {
            final already = prev.map((m) => m.wordKr).toSet();
            final add = list.where((m) => !already.contains(m.wordKr));
            return [...prev, ...add];
          }, ifAbsent: () => list);

          // from 매핑 (서버가 originalQuery 줬을 때만)
          if (from != null && from.isNotEmpty) {
            final normFrom = _normalize(from);
            newOrig2Can[normFrom] = canonical;
            (newCan2Origs[canonical] ??= <String>{}).add(normFrom);
          }
        }

        // 원문이 결과 항목에서 빠진 경우: 동일 철자가 결과에 있으면 원문=표제어 매핑
        for (final origRaw in _wordsToAdd) {
          final orig = _normalize(origRaw);
          if (newOrig2Can.containsKey(orig)) continue;
          if (newMeanings.containsKey(orig)) {
            newOrig2Can[orig] = orig;
            (newCan2Origs[orig] ??= <String>{}).add(orig);
          }
        }
        // 🔥 오타 전용 fallback:
        // - 입력 단어(orig)가 canonical 목록(canonicalNorms)에 "한 번도" 안 나오고
        // - 아직 어떤 canonical 에도 매핑되지 않았으면
        //   → 같은 인덱스의 canonical 에 from 으로 붙여준다. (porple → purple)
        for (int i = 0;
            i < _wordsToAdd.length && i < canonicalKeys.length;
            i++) {
          final origNorm = _normalize(_wordsToAdd[i]);

          // 이미 매핑이 있다면 (originalQuery로 들어왔거나 direct 매핑된 경우) 스킵
          if (newOrig2Can.containsKey(origNorm)) continue;

          // 이 단어가 canonical 로도 존재한다면(예: made), 오타 아님 → 스킵
          if (canonicalNorms.contains(origNorm)) continue;

          // 여기까지 왔으면 오타에 가깝다고 보고,
          // 같은 인덱스의 canonical 에 from 으로 매핑
          final canonical = canonicalKeys[i];
          newOrig2Can[origNorm] = canonical;
          (newCan2Origs[canonical] ??= <String>{}).add(origNorm);
        }

        setState(() {
          _wordsWithMeanings = newMeanings;
          _selectedMeaningIds.clear();
          for (final k in _wordsWithMeanings.keys) {
            _selectedMeaningIds[k] = <String>{};
          }
          _origToCanonical
            ..clear()
            ..addAll(newOrig2Can);
          _canonicalToOrigs
            ..clear()
            ..addAll(newCan2Origs);
        });

        // 🔥 "못 찾은 단어" 계산: 매핑/직접/from 어디에도 없으면 진짜 못 찾은 것
        final notMatched = _wordsToAdd.where((origRaw) {
          final orig = _normalize(origRaw);

          final mapped = _origToCanonical.containsKey(orig);
          final direct = _wordsWithMeanings.containsKey(orig);
          final viaFrom =
              _canonicalToOrigs.values.any((froms) => froms.contains(orig));

          return !(mapped || direct || viaFrom);
        }).toList();

        if (notMatched.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('뜻을 찾지 못한 항목: ${notMatched.join(", ")}')),
          );
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인 만료: 다시 로그인해주세요.')),
          );
        }
      } else {
        final body = response.body.isNotEmpty ? ' / ${response.body}' : '';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('뜻 조회 실패 (${response.statusCode})$body')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('뜻 조회 중 오류 발생')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveToWordbook() async {
    // 선택된 표제어만 payload 구성 (표제어 = 교정된 영단어)
    final selectedData = _selectedMeaningIds.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => {
              'wordEn': e.key, // ✅ canonical
              'wordKrList': e.value.toList(), // 선택한 뜻들
            })
        .toList();

    if (selectedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 뜻을 선택해주세요.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    setState(() => _loading = true);

    final url = Uri.parse(
      'https://semiconical-shela-loftily.ngrok-free.dev/api/words/personal-wordbook/${widget.wordbookId}',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'words': selectedData}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('단어가 단어장에 성공적으로 등록되었습니다.')),
          );
        }
        setState(() {
          _wordsToAdd.clear();
          _wordsWithMeanings.clear();
          _selectedMeaningIds.clear();
          _origToCanonical.clear(); // ✅ 매핑 초기화
          _canonicalToOrigs.clear(); // ✅ 매핑 초기화
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인 만료: 다시 로그인해주세요.')),
          );
        }
      } else {
        final body = response.body.isNotEmpty ? ' / ${response.body}' : '';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('단어장 등록 실패 (${response.statusCode})$body')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장 저장 중 오류 발생')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // --- 배경 + 메인 UI ---
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background/background.png"),
                  fit: BoxFit.contain,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // --- 영단어 입력창 ---
                    Padding(
                      padding: const EdgeInsets.only(top: 55),
                      child: Align(
                        alignment: const Alignment(-0.4, 0),
                        child: SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _wordController,
                            decoration: InputDecoration(
                              labelText: '영단어 입력',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () async {
                                  _addWordToList();
                                  await _fetchMeanings();
                                },
                              ),
                            ),
                            onSubmitted: (_) async {
                              _addWordToList();
                              await _fetchMeanings();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- 추가된 단어 칩 ---
                    if (_wordsToAdd.isNotEmpty)
                      Align(
                        alignment: const Alignment(-0.1, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _wordsToAdd
                              .map((w) => Chip(
                                    label: Text(w),
                                    backgroundColor: const Color(0xFFF6F0E9),
                                    onDeleted: () async {
                                      // 1) 칩 목록에서만 먼저 제거
                                      setState(() {
                                        _wordsToAdd.remove(w);
                                      });

                                      // 2) 남은 단어가 없으면 뜻/매핑 전부 초기화
                                      if (_wordsToAdd.isEmpty) {
                                        setState(() {
                                          _wordsWithMeanings.clear();
                                          _selectedMeaningIds.clear();
                                          _origToCanonical.clear();
                                          _canonicalToOrigs.clear();
                                        });
                                      } else {
                                        // 3) 남은 단어들 기준으로 다시 뜻 조회
                                        await _fetchMeanings();
                                      }
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // --- 뜻 조회 결과 ---
                    Expanded(
                      child: _wordsWithMeanings.isEmpty
                          ? Align(
                              alignment: const Alignment(-0.1, 0),
                              child: const Text('뜻이 없습니다.'),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children:
                                    _wordsWithMeanings.entries.map((entry) {
                                  final canonical = entry.key;
                                  final meanings = entry.value;

                                  // 제목: apple (from: apble, aple, ...)
                                  final froms = _canonicalToOrigs[canonical] ??
                                      const <String>{};
                                  final title = froms.isEmpty ||
                                          (froms.length == 1 &&
                                              froms.first == canonical)
                                      ? canonical
                                      : '$canonical (from: ${froms.join(", ")})';

                                  return Align(
                                    alignment: const Alignment(-0.4, 0),
                                    child: SizedBox(
                                      width: 300,
                                      child: Card(
                                        color: const Color.fromRGBO(0, 0, 0, 0),
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: meanings.map((m) {
                                                  final selected =
                                                      _selectedMeaningIds[
                                                                  canonical]
                                                              ?.contains(
                                                                  m.wordKr) ??
                                                          false;
                                                  return ChoiceChip(
                                                    label: Text(m.wordKr),
                                                    selected: selected,
                                                    selectedColor:
                                                        const Color.fromARGB(
                                                            255, 162, 180, 234),
                                                    backgroundColor:
                                                        const Color(0xFFF6F0E9),
                                                    onSelected: (val) {
                                                      setState(() {
                                                        _selectedMeaningIds
                                                            .putIfAbsent(
                                                                canonical,
                                                                () =>
                                                                    <String>{}); // 방어
                                                        if (val) {
                                                          _selectedMeaningIds[
                                                                  canonical]!
                                                              .add(m.wordKr);
                                                        } else {
                                                          _selectedMeaningIds[
                                                                  canonical]!
                                                              .remove(m.wordKr);
                                                        }
                                                      });
                                                    },
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),

                    // --- 단어장 저장 버튼 ---
                    if (_selectedMeaningIds.values.any((v) => v.isNotEmpty))
                      Align(
                        alignment: const Alignment(-0.1, 0),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _saveToWordbook,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFCC8C8),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                  color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text('단어장에 저장'),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // --- 나가기 버튼 ---
                    Align(
                      alignment: const Alignment(-0.1, 0),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                  color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text('나가기'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- FakeProgressBar 오버레이 ---
            if (_loading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Align(
                  alignment: Alignment(-0.6, 0), // 중앙에서 더 왼쪽
                  child: FakeProgressBar(
                    width: 250,
                    height: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
