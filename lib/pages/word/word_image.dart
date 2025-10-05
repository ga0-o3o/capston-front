// lib/pages/word/word_image.dart
import 'package:flutter/material.dart';

Future<void> openImageSourceSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    builder: (_) => Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.camera),
          title: const Text('Camera'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Gallery'),
          onTap: () {},
        ),
      ],
    ),
  );
}

// uploadFlow 관련 함수도 이곳에 작성
