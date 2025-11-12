import 'package:flutter/material.dart';

Future<void> showWordbookOptions(
  BuildContext context, {
  required VoidCallback onEdit,
  required VoidCallback onMove,
  required VoidCallback onDelete,
}) async {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('수정'),
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('이동'),
            onTap: () {
              Navigator.pop(context);
              onMove();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('삭제'),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    ),
  );
}
