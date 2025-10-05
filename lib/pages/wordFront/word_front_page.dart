import 'package:flutter/material.dart';
import 'wordbook_card.dart';
import 'wordbook_service.dart';
import 'wordbook_dialogs.dart';
import 'wordbook_options.dart';
import '../loading_page.dart';
import '../word/word_menu_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordFrontPage extends StatefulWidget {
  const WordFrontPage({super.key});

  @override
  State<WordFrontPage> createState() => _WordFrontPageState();
}

class _WordFrontPageState extends State<WordFrontPage> {
  List<Map<String, dynamic>> _wordBooks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWordbooks();
  }

  Future<void> _loadWordbooks({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);

    final list = await WordbookService.fetchWordbooks(context);

    setState(() {
      _wordBooks = list;
      if (showLoading) _loading = false;
    });
  }

  Future<void> _addWordbook() async {
    final title = await showWordbookNameDialog(context);
    if (title == null || title.isEmpty) return;

    final data = await WordbookService.addWordbook(title, context);
    if (data != null) {
      setState(() {
        // 새 단어장만 맨 앞에 insert
        _wordBooks.insert(0, {
          'title': data['title'] ?? '제목 없음',
          'id': data['personalWordbookId'] ?? 0,
          'color':
              Colors.primaries[_wordBooks.length % Colors.primaries.length],
          'image':
              'assets/images/wordBook${(data['personalWordbookId'] ?? 0) % 3 + 1}.png',
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장 추가 실패')),
      );
    }
  }

  void _showOptions(int index) {
    final book = _wordBooks[index];
    showWordbookOptions(
      context,
      onEdit: () async {
        final newTitle =
            await showWordbookNameDialog(context, initial: book['title']);
        if (newTitle == null || newTitle.isEmpty) return;
        final success =
            await WordbookService.editWordbook(book['id'], newTitle, context);
        if (success) setState(() => _wordBooks[index]['title'] = newTitle);
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

        final success =
            await WordbookService.deleteWordbook(book['id'], context);
        if (success) setState(() => _wordBooks.removeAt(index));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: _loading
          ? const LoadingPage()
          : _wordBooks.isEmpty
              ? const Center(child: Text('단어장이 없습니다.'))
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _wordBooks.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 3 / 2,
                    ),
                    itemBuilder: (context, index) {
                      return WordbookCard(
                        book: _wordBooks[index],
                        onTap: () => _showOptions(index),
                      );
                    },
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
