import 'package:flutter/material.dart';
import 'wordbook_card.dart';
import 'wordbook_service.dart';
import 'wordbook_dialogs.dart';
import 'wordbook_options.dart';
import '../word/word_menu_page.dart';
import '../skeleton_wordbook.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordFrontPage extends StatefulWidget {
  const WordFrontPage({super.key});

  @override
  State<WordFrontPage> createState() => _WordFrontPageState();
}

class _WordFrontPageState extends State<WordFrontPage> {
  List<Map<String, dynamic>> _wordBooks = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filteredBooks = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadWordbooks();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredBooks = _wordBooks
          .where((b) => (b['title'] as String).toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _loadWordbooks({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);

    final list = await WordbookService.fetchWordbooks(context);

    if (!mounted) return;

    setState(() {
      _wordBooks = list.reversed.toList();
      _filteredBooks = List.from(_wordBooks);
      if (showLoading) _loading = false;
    });
  }

  Future<void> _addWordbook() async {
    final title = await showWordbookNameDialog(context);
    if (title == null || title.isEmpty) return;

    setState(() => _loading = true); // 🌟 skeleton 시작

    final data = await WordbookService.addWordbook(title, context);

    if (!mounted) return;

    setState(() {
      if (data != null) {
        _wordBooks.insert(0, {
          'title': data['title'] ?? '제목 없음',
          'id': data['personalWordbookId'] ?? data['id'],
          'color':
              Colors.primaries[_wordBooks.length % Colors.primaries.length],
          'image':
              'assets/images/wordBook${(data['personalWordbookId'] ?? data['id'] ?? 0) % 3 + 1}.png',
        });
        _filteredBooks = List.from(_wordBooks);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장 추가 실패')),
        );
      }
      _loading = false; // 🌟 skeleton 끝
    });
  }

  void _showOptions(int index) {
    final book = _wordBooks[index];
    showWordbookOptions(
      context,
      onEdit: () async {
        final newTitle =
            await showWordbookNameDialog(context, initial: book['title']);
        if (newTitle == null || newTitle.isEmpty) return;

        setState(() => _loading = true); // 🌟 skeleton 시작
        final success =
            await WordbookService.editWordbook(book['id'], newTitle, context);

        if (!mounted) return;

        setState(() {
          if (success) {
            _wordBooks[index]['title'] = newTitle;
            _filteredBooks = List.from(_wordBooks);
          }
          _loading = false; // 🌟 skeleton 끝
        });
      },
      onMove: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('selectedWordbookId', book['id']);
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WordMenuPage(wordbookId: book['id']),
            ));
      },
      onDelete: () async {
        final confirm = await showDeleteWordbookDialog(context, book['title']);
        if (!confirm) return;

        setState(() => _loading = true); // 🌟 skeleton 시작
        final success =
            await WordbookService.deleteWordbook(book['id'], context);

        if (!mounted) return;

        setState(() {
          if (success) {
            _wordBooks.removeAt(index);
            _filteredBooks = List.from(_wordBooks);
          }
          _loading = false; // 🌟 skeleton 끝
        });
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: _loading
          ? const SkeletonGrid(
              itemCount: 6,
              topPadding: 30,
            )
          : _wordBooks.isEmpty
              ? const Center(child: Text('단어장이 없습니다.'))
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // 검색창
                      TextField(
                        controller: _searchCtrl,
                        onTap: () => setState(() => _isSearching = true),
                        onEditingComplete: () =>
                            setState(() => _isSearching = false),
                        decoration: InputDecoration(
                          hintText: '단어장 검색',
                          filled: true,
                          fillColor: _isSearching
                              ? const Color(0xFF3D4C63)
                              : Colors.white,
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
                      // GridView
                      Expanded(
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _filteredBooks.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 3 / 2,
                          ),
                          itemBuilder: (context, index) {
                            return WordbookCard(
                              book: _filteredBooks[index],
                              onTap: () => _showOptions(index),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton(
              onPressed: _addWordbook,
              backgroundColor: const Color(0xFF4E6E99),
              child: const Icon(Icons.add, size: 32, color: Colors.white),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
