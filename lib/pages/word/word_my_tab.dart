import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_create.dart';
import 'word_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'word_image.dart';

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
      final words = await WordApi.fetchWords(widget.wordbookId);
      setState(() => _words = words);
      print('✅ Total words loaded: ${_words.length}');
      // 각 단어 정보 출력
      for (var w in _words) {
        print('word: ${w.word}');
        print('wordKr: ${w.wordKr.join(", ")}');
        print('wordbookId: ${widget.wordbookId}');
        print('personalWordbookWordId: ${w.personalWordbookWordId}');
        print('favorite: ${w.favorite}');
      }
    } catch (e) {
      print('❌ 단어 조회 에러: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteWords(int wordbookId, int wordId) async {
    try {
      final success = await WordApi.deleteWord(wordbookId, wordId);
      if (success)
        _words.removeWhere((w) => w.personalWordbookWordId == wordId);
    } catch (e) {
      print('단어 삭제 에러: $e');
    }
  }

  Future<void> _showMenu(WordItem it) async {
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
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('삭제'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'delete') {
      // 삭제 처리
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('단어 삭제'),
          content: const Text('정말로 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _deleteWords(widget.wordbookId, it.personalWordbookWordId);
        setState(() {
          _words.removeWhere(
              (w) => w.personalWordbookWordId == it.personalWordbookWordId);
          _filteredWords.removeWhere(
              (w) => w.personalWordbookWordId == it.personalWordbookWordId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 삭제되었습니다.')),
        );
      }
    } else if (choice == 'edit') {}
  }

  Future<void> _showAddOptions(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
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

    if (result == 'manual') {
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
    } else if (result == 'image') {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 400,
            height: 500,
            child: WordImageUploader(
              wordbookId: widget.wordbookId,
              hsvValues: {'h': 0, 's': 0, 'v': 0},
            ),
          ),
        ),
      );
    }

    widget.onAdd();
    _fetchWords();
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
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showMenu(word), // 카드 클릭 시 메뉴 표시
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
                                            : Icons.star_border,
                                        color: Colors.amber[700],
                                      ),
                                      onPressed: () async {
                                        final success =
                                            await WordApi.toggleFavorite(
                                                widget.wordbookId,
                                                word.personalWordbookWordId);
                                        if (success) {
                                          setState(() =>
                                              word.favorite = !word.favorite);
                                        }
                                      },
                                    )
                                  ],
                                ),
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
