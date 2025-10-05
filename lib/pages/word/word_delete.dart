// lib/pages/word/word_delete.dart
import 'package:flutter/material.dart';
import 'word_api.dart';

Future<void> confirmDelete(
  BuildContext context,
  int wordbookId,
  int wordId, {
  required VoidCallback onDeleted,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Word'),
      content: const Text('정말 삭제하시겠습니까?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete')),
      ],
    ),
  );

  if (result == true) {
    await WordApi.deleteWord(wordbookId, wordId);
    onDeleted();
  }
}
