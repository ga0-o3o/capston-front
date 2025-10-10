import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_create.dart';
import 'word_edit.dart';
import 'word_api.dart';
import 'word_image.dart';
import 'word_dialogs.dart';
import '../loading_page.dart';

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
    _loadInitialWords();
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

  Future<void> _loadInitialWords() async {
    setState(() => _loading = true);
    await _fetchWords();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchWords() async {
    try {
      final words = await WordApi.fetchWords(widget.wordbookId);

      // ✅ 중복 뜻 제거 + groupWordIds 채우기
      final cleanedWords = words.map((w) {
        final uniqueMeanings = w.wordKr.toSet().toList();

        // 서버에서 가져온 wordIds를 groupWordIds로 초기화
        final groupWordIds = List<int>.from((w.groupWordIds.isNotEmpty
            ? w.groupWordIds
            : [w.personalWordbookWordId]));

        return w.copyWith(
          wordKr: uniqueMeanings, // UI용
          wordKrOriginal: w.wordKr, // 서버 원본
          groupWordIds: groupWordIds,
        );
      }).toList();

      setState(() => _words = cleanedWords);
    } catch (e) {
      print('❌ 단어 조회 에러: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      final confirm = await showDeleteWordDialog(context, it.word);
      if (confirm == true) {
        final success = await WordApi.deleteWord(
            widget.wordbookId, it.personalWordbookWordId);
        if (success) {
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
      }
    } else if (choice == 'edit') {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent, // Dialog 자체 배경 완전 투명
          elevation: 0, // 그림자 제거
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 400,
            height: 600,
            child: WordEditPage(
              wordbookId: widget.wordbookId,
              wordItem: it,
            ),
          ),
        ),
      );

      if (result == true) {
        await _fetchWords();
      }
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
                ? const LoadingPage()
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
                              if (word.word != draggedWord.word) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('같은 단어끼리만 병합할 수 있습니다.')),
                                );
                                return;
                              }

                              final mergedIds = [
                                ...word.groupWordIds,
                                ...draggedWord.groupWordIds,
                              ];
                              final mergedSet = mergedIds.toSet().toList();
                              final success = await WordApi.mergeWords(
                                  widget.wordbookId, mergedSet);
                              if (success) {
                                setState(() {
                                  word.groupWordIds = mergedSet;
                                  draggedWord.groupWordIds = mergedSet;
                                });
                                await _fetchWords(); // ✅ 서버 병합 결과 즉시 반영
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              return LongPressDraggable<WordItem>(
                                data: word,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Card(
                                    color: const Color.fromARGB(
                                        255, 162, 180, 234),
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
                                                  maxLines: null,
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
      floatingActionButton: _loading
          ? null // 로딩 중에는 버튼 숨김
          : FloatingActionButton(
              onPressed: () => _showAddOptions(context),
              backgroundColor: const Color(0xFF4E6E99),
              child: const Icon(Icons.add, size: 32, color: Colors.white),
            ),
    );
  }
}
