import 'package:flutter/material.dart';
import 'word_item.dart';

class WordQuizTab extends StatelessWidget {
  final List<WordItem> words;

  const WordQuizTab({Key? key, required this.words}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('퀴즈 기능 구현 예정: 단어 수 ${words.length}'),
    );
  }
}
