import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_list_tab.dart';

class WordFavoriteTab extends StatelessWidget {
  final int wordbookId;
  final List<WordItem> words;
  final VoidCallback onDelete;

  const WordFavoriteTab({
    Key? key,
    required this.wordbookId,
    required this.words,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WordListTab(
      items: words.where((w) => w.favorite).toList(),
      onDelete: (item) async {
        onDelete();
      },
      showFavoritesOnly: true,
    );
  }
}
