import 'package:flutter/material.dart';
import 'word_api.dart';
import 'word_item.dart';
import '../loading_page.dart';

class WordFavoriteTab extends StatefulWidget {
  final int wordbookId;

  const WordFavoriteTab({super.key, required this.wordbookId});

  @override
  State<WordFavoriteTab> createState() => _WordFavoriteTabState();
}

class _WordFavoriteTabState extends State<WordFavoriteTab> {
  List<WordItem> _words = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchWords();
  }

  Future<void> _fetchWords() async {
    setState(() => _loading = true);
    try {
      final words = await WordApi.fetchWords(widget.wordbookId);
      // 즐겨찾기된 단어만 필터링
      setState(() => _words = words.where((w) => w.favorite).toList());
      print('✅ 즐겨찾기 단어 로드 완료: ${_words.length}');
    } catch (e) {
      print('❌ 단어 조회 에러: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(WordItem word) async {
    final success = await WordApi.toggleFavorite(
        widget.wordbookId, word.personalWordbookWordId);
    if (success) {
      setState(() {
        word.favorite = !word.favorite;
        // 즐겨찾기 해제 시 리스트에서 제거
        if (!word.favorite) _words.remove(word);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('즐겨찾기 상태 변경 실패')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingPage();
    }

    if (_words.isEmpty) {
      return const Center(child: Text('즐겨찾기 단어가 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchWords,
      child: ListView.builder(
        itemCount: _words.length,
        itemBuilder: (context, index) {
          final word = _words[index];
          return Card(
            elevation: 4,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            margin:
                const EdgeInsets.only(top: 20, bottom: 8, left: 16, right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                        word.favorite ? Icons.star : Icons.star_border,
                        color: Colors.amber[700],
                      ),
                      onPressed: () => _toggleFavorite(word),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
