// lib/pages/word/word_list_tab.dart
import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_api.dart';

typedef OnDeleteCallback = Future<void> Function(WordItem item);

class WordListTab extends StatefulWidget {
  final List<WordItem> items;
  final OnDeleteCallback onDelete;
  final bool showFavoritesOnly; // 즐겨찾기만 표시할지 여부

  const WordListTab({
    Key? key,
    required this.items,
    required this.onDelete,
    this.showFavoritesOnly = false,
  }) : super(key: key);

  @override
  State<WordListTab> createState() => _WordListTabState();
}

class _WordListTabState extends State<WordListTab> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _removeItem(WordItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('${item.word} - ${item.wordKr.join(', ')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );

    if (ok == true) {
      await widget.onDelete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기 필터 적용
    final filteredItems = widget.showFavoritesOnly
        ? widget.items.where((w) => w.favorite).toList()
        : widget.items;

    // 검색 필터 적용
    final displayedItems = _searchQuery.isEmpty
        ? filteredItems
        : filteredItems
            .where((e) =>
                e.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.wordKr
                    .join(', ')
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: '검색',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: displayedItems.isEmpty
              ? const Center(child: Text('단어가 없습니다.'))
              : ListView.builder(
                  itemCount: displayedItems.length,
                  itemBuilder: (_, idx) {
                    final item = displayedItems[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text(item.word),
                        subtitle: Text(item.wordKr.join(', ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeItem(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
