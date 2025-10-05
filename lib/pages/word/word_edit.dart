// lib/pages/word/word_edit.dart
import 'package:flutter/material.dart';
import 'word_item.dart';

class WordEditTab extends StatelessWidget {
  final WordItem word;
  final VoidCallback onEdited;

  const WordEditTab({Key? key, required this.word, required this.onEdited})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final _controller = TextEditingController(text: word.word);

        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('단어 편집'),
              content: TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: '영단어'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    word.word = _controller.text; // 바로 수정 가능
                    onEdited(); // 콜백 호출
                    Navigator.of(context).pop();
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
      child: const Text('Edit Word'),
    );
  }
}
