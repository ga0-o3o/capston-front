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
  List<String> _wordsToAdd = [];
  Map<String, List<WordMeaning>> _wordsWithMeanings = {};
  Map<String, Set<String>> _selectedMeaningIds = {}; // ⚡ int -> String
  bool _loading = false;

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  void _addWordToList() {
    final word = _wordController.text.trim();
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

    final url = Uri.parse('http://localhost:8080/api/words/save-from-api');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'wordsEn': _wordsToAdd}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, List<WordMeaning>> meanings = {};

        for (var item in data) {
          final wordEn = item['wordEn'];
          final wordMeanings = (item['wordMeanings'] as List)
              .map((e) => WordMeaning(
                    wordId: e['wordId'],
                    wordKr: e['wordKr'],
                  ))
              .toList();
          meanings[wordEn] = wordMeanings;
          _selectedMeaningIds[wordEn] = <String>{}; // ⚡ String 사용
        }

        setState(() {
          _wordsWithMeanings = meanings;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('뜻 조회 실패')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('뜻 조회 중 오류 발생')),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _saveToWordbook() async {
    final selectedData = _selectedMeaningIds.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => {
              'wordEn': e.key,
              'wordKrList': e.value.toList(),
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
        'http://localhost:8080/api/words/personal-wordbook/${widget.wordbookId}');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'words': selectedData}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 단어장에 성공적으로 등록되었습니다.')),
        );
        setState(() {
          _wordsToAdd.clear();
          _wordsWithMeanings.clear();
          _selectedMeaningIds.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장 등록 실패')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장 저장 중 오류 발생')),
      );
    }

    setState(() => _loading = false);
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
                  image: AssetImage("images/background.png"),
                  fit: BoxFit.cover,
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
                          children: _wordsToAdd
                              .map((w) => Chip(
                                    label: Text(w),
                                    backgroundColor: const Color(0xFFF6F0E9),
                                    onDeleted: () {
                                      setState(() {
                                        _wordsToAdd.remove(w);
                                        _wordsWithMeanings.remove(w);
                                        _selectedMeaningIds.remove(w);
                                      });
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
                                  final word = entry.key;
                                  final meanings = entry.value;
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
                                              Text(word,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 6,
                                                children: meanings.map((m) {
                                                  final selected =
                                                      _selectedMeaningIds[word]!
                                                          .contains(m.wordKr);
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
                                                        if (val) {
                                                          _selectedMeaningIds[
                                                                  word]!
                                                              .add(m.wordKr);
                                                        } else {
                                                          _selectedMeaningIds[
                                                                  word]!
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
                  alignment: Alignment(-0.6, 0), // 중앙에서 더 왼쪽으로 이동
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
