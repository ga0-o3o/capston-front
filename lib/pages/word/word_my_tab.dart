import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_create.dart';
import 'word_edit.dart';
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

  Future<void> _fetchWords() async {
    setState(() => _loading = true);
    try {
      final words = await WordApi.fetchWords(widget.wordbookId);
      setState(() => _words = words);
    } catch (e) {
      print('❌ 단어 조회 에러: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteWords(int wordbookId, int wordId) async {
    try {
      final success = await WordApi.deleteWord(wordbookId, wordId);
      if (success) {
        _words.removeWhere((w) => w.personalWordbookWordId == wordId);
      }
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
    } else if (choice == 'edit') {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 400,
            height: 500,
            child: WordEditPage(
              wordbookId: widget.wordbookId,
              wordItem: it,
            ),
          ),
        ),
      );

      await _fetchWords();
    }
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
        barrierColor: Colors.transparent, // 배경 어둡게 깔리는 기본 색 제거, 완전 투명
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent, // Dialog 자체 배경 완전 투명
          elevation: 0, // 그림자 제거
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 400,
            height: 600,
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              onTap: () => setState(() => _isSearching = true),
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
                          return DragTarget<WordItem>(
                            onWillAccept: (draggedWord) => draggedWord != word,
                            onAccept: (draggedWord) async {
                              // 병합 조건: 같은 단어(wordEn)끼리만
                              if (word.word != draggedWord.word) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('같은 단어끼리만 병합할 수 있습니다.')),
                                );
                                return; // 병합 중단
                              }

                              // 드래그한 대상이 이미 그룹에 속해 있다면 그룹 전체 가져오기
                              List<int> wordIdsToMerge = [];

                              // 현재 카드 그룹
                              if (word.groupId != null) {
                                wordIdsToMerge.addAll(
                                  _words
                                      .where((w) => w.groupId == word.groupId)
                                      .map((w) => w.personalWordbookWordId),
                                );
                              } else {
                                wordIdsToMerge.add(word.personalWordbookWordId);
                              }

                              // 드래그한 카드 포함
                              if (draggedWord.groupId != null) {
                                wordIdsToMerge.addAll(
                                  _words
                                      .where((w) =>
                                          w.groupId == draggedWord.groupId)
                                      .map((w) => w.personalWordbookWordId),
                                );
                              } else {
                                wordIdsToMerge
                                    .add(draggedWord.personalWordbookWordId);
                              }

                              // 중복 제거
                              wordIdsToMerge = wordIdsToMerge.toSet().toList();

                              // 서버 병합 호출
                              final success = await WordApi.mergeWords(
                                  widget.wordbookId, wordIdsToMerge);

                              if (success) {
                                await _fetchWords();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('단어 그룹 병합 완료!')),
                                );
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              return LongPressDraggable<WordItem>(
                                data: word,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Card(
                                    elevation: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      width: MediaQuery.of(context).size.width -
                                          24,
                                      child: Text(
                                        word.word,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                child: Card(
                                  color: candidateData.isNotEmpty
                                      ? Colors.blue[50]
                                      : Colors.white,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _showMenu(word),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                setState(() => word.favorite =
                                                    !word.favorite);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
