// lib/pages/word/word_create.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'word_item.dart';
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
  Map<String, List<String>> _wordsWithMeanings = {};
  Map<String, Set<String>> _selectedMeanings = {}; // 선택된 뜻
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

    print('📌 _fetchMeanings 호출, 단어 리스트: $_wordsToAdd');

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

      print('📌 HTTP 상태 코드: ${response.statusCode}');
      print('📌 응답 바디: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, List<String>> meanings = {};
        for (var item in data) {
          meanings[item['wordEn']] =
              List<String>.from(item['wordKr'] ?? <String>[]);
          _selectedMeanings[item['wordEn']] = <String>{}; // 초기화
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
      print('❌ _fetchMeanings 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('뜻 조회 중 오류 발생')),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _saveToWordbook() async {
    // 선택된 뜻만 전송
    final selectedData = _selectedMeanings.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => {'wordEn': e.key, 'wordKrList': e.value.toList()})
        .toList();

    if (selectedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 뜻을 선택해주세요.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    print('📌 _saveToWordbook 호출, 보내는 데이터: $selectedData');

    setState(() => _loading = true);

    final url = Uri.parse(
        'http://localhost:8080/api/words/personal-wordbook/${widget.wordbookId}');
    final body = {'words': selectedData};

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('📌 HTTP 상태 코드: ${response.statusCode}');
      print('📌 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 단어장에 성공적으로 등록되었습니다.')),
        );
        setState(() {
          _wordsToAdd.clear();
          _wordsWithMeanings.clear();
          _selectedMeanings.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장 등록 실패')),
        );
      }
    } catch (e) {
      print('❌ _saveToWordbook 에러: $e');
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
        backgroundColor: const Color(0xFFF6F0E9),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- 영단어 입력창 ---
              TextField(
                controller: _wordController,
                decoration: InputDecoration(
                  labelText: '영단어 입력',
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
              const SizedBox(height: 12),
              // --- 단어 Chip ---
              if (_wordsToAdd.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _wordsToAdd
                      .map((w) => Chip(
                            label: Text(w),
                            onDeleted: () {
                              setState(() {
                                _wordsToAdd.remove(w);
                                _wordsWithMeanings.remove(w);
                                _selectedMeanings.remove(w);
                              });
                            },
                          ))
                      .toList(),
                ),
              const SizedBox(height: 12),
              // --- 뜻 선택 리스트 ---
              Expanded(
                child: _wordsWithMeanings.isEmpty
                    ? const Center(child: Text('뜻이 없습니다.'))
                    : SingleChildScrollView(
                        child: Column(
                          children: _wordsWithMeanings.entries.map((entry) {
                            final word = entry.key;
                            final meanings = entry.value;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(word,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      children: meanings.map((m) {
                                        final selected =
                                            _selectedMeanings[word]!
                                                .contains(m);
                                        return ChoiceChip(
                                          label: Text(m),
                                          selected: selected,
                                          onSelected: (val) {
                                            setState(() {
                                              if (val) {
                                                _selectedMeanings[word]!.add(m);
                                              } else {
                                                _selectedMeanings[word]!
                                                    .remove(m);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              // --- 단어장 저장 버튼 ---
              if (_selectedMeanings.values.any((v) => v.isNotEmpty))
                ElevatedButton(
                  onPressed: _loading ? null : _saveToWordbook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCC8C8), // 배경색
                    foregroundColor: Colors.black, // 글자색
                    minimumSize: const Size(100, 40), // 버튼 최소 크기
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0), // 모서리 각지게
                      side: const BorderSide(
                          color: Colors.black, width: 2), // 테두리
                    ),
                  ),
                  child: const Text('단어장에 저장'),
                ),
              const SizedBox(height: 12),
              // --- 나가기 버튼 ---
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99), // 배경색
                  foregroundColor: Colors.white, // 글자색
                  minimumSize: const Size(100, 40), // 버튼 최소 크기
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0), // 모서리 각지게
                    side:
                        const BorderSide(color: Colors.black, width: 2), // 테두리
                  ),
                ),
                child: const Text('나가기'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
