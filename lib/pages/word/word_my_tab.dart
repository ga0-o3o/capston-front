import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_create.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WordMyTab extends StatefulWidget {
  final int wordbookId;
  final Future<void> Function(WordItem) onDelete;
  final VoidCallback onAdd;

  const WordMyTab({
    Key? key,
    required this.wordbookId,
    required this.onDelete,
    required this.onAdd,
  }) : super(key: key);

  @override
  State<WordMyTab> createState() => _WordMyTabState();
}

class _WordMyTabState extends State<WordMyTab> {
  List<WordItem> _words = [];
  List<WordItem> _filteredWords = [];
  bool _loading = false;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchWords();
    _searchCtrl.addListener(() {
      final query = _searchCtrl.text.toLowerCase();
      setState(() {
        _filteredWords = _words
            .where((word) =>
                word.word.toLowerCase().contains(query) ||
                word.wordKr.any((kr) => kr.toLowerCase().contains(query)))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredWords = _words
          .where((word) =>
              word.word.toLowerCase().contains(query) ||
              word.wordKr.any((kr) => kr.toLowerCase().contains(query)))
          .toList();
    });
  }

  Future<void> _fetchWords() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final savedWordbookId = prefs.getInt('selectedWordbookId');

      if (token == null || token.isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = Uri.parse(
          'http://localhost:8080/api/v1/wordbooks/$savedWordbookId/words');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;

        final loadedWords = data.map((e) {
          final wordEn = e['wordEn'] ?? '';
          final wordKrList = List<String>.from(e['wordKr'] ?? []);
          return WordItem(
            personalWordbookWordId: e['personalWordbookWordId'] ?? 0,
            word: wordEn,
            wordKr: wordKrList,
            favorite: e['favorite'] ?? false,
          );
        }).toList();

        setState(() => _words = loadedWords);
        print('✅ Total words loaded: ${_words.length}');
      } else if (response.statusCode == 403) {
        throw Exception('접근 권한이 없습니다. 다시 로그인 해주세요.');
      } else {
        throw Exception('단어 조회 실패 (${response.statusCode})');
      }
    } catch (e, st) {
      print('❌ 단어 조회 에러: $e');
      print(st);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddOptions(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
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
          ],
        ),
      ),
    );

    if (result != null && (result == 'manual' || result == 'image')) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 400,
            height: 500,
            child: WordCreatePage(wordbookId: widget.wordbookId),
          ),
        ),
      );
      widget.onAdd();
      _fetchWords(); // 단어 추가 후 목록 갱신
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayWords = _searchCtrl.text.isEmpty ? _words : _filteredWords;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              onTap: () {
                setState(() => _isSearching = true);
              },
              decoration: InputDecoration(
                hintText: '단어 검색',
                filled: true,
                fillColor:
                    _isSearching ? const Color(0xFF3D4C63) : Colors.white,
                hintStyle: TextStyle(
                  color: _isSearching ? Colors.white70 : Colors.grey,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: _isSearching ? Colors.white : Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                color: _isSearching ? Colors.white : Colors.black,
              ),
            ),
          ),

          // 단어 목록
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : displayWords.isEmpty
                    ? const Center(
                        child: Text(
                          '단어가 존재하지 않습니다.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: displayWords.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final word = displayWords[index];
                          return Card(
                            elevation: 4,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          word.word,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3A3A3A),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          word.wordKr.join(', '),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF5A5A5A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      word.favorite
                                          ? Icons.star
                                          : Icons.star_border_outlined,
                                      color: word.favorite
                                          ? Colors.amber
                                          : Colors.grey,
                                    ),
                                    onPressed: () async {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final token =
                                          prefs.getString('jwt_token') ?? '';
                                      final savedWordbookId =
                                          prefs.getInt('selectedWordbookId');
                                      final wordId =
                                          word.personalWordbookWordId;

                                      final url = Uri.parse(
                                          'http://localhost:8080/api/words/$savedWordbookId/words/$wordId/toggle-favorite');

                                      print('📡 [FAVORITE] 요청 URL: $url');
                                      print('📡 [FAVORITE] JWT 토큰: $token');

                                      try {
                                        final res = await http.put(
                                          url,
                                          headers: {
                                            'Authorization': 'Bearer $token',
                                          },
                                        );

                                        print(
                                            '📡 [FAVORITE] 응답 코드: ${res.statusCode}');
                                        print(
                                            '📡 [FAVORITE] 응답 본문: ${res.body}');

                                        if (res.statusCode == 200) {
                                          setState(() =>
                                              word.favorite = !word.favorite);
                                          print(
                                              '✅ 즐겨찾기 상태 변경됨: ${word.favorite}');
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    '즐겨찾기 상태 변경 실패: ${res.statusCode}')),
                                          );
                                        }
                                      } catch (e) {
                                        print('❌ [FAVORITE] 오류: $e');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('서버와 연결할 수 없습니다: $e')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        backgroundColor: const Color(0xFF4E6E99),
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }
}
