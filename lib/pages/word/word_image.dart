// word_image.dart
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/definition_item.dart';
import '../../services/django_api.dart';
import '../../widgets/review_words_sheet.dart';
import '../../widgets/review_meanings_sheet.dart';

class WordImageUploader extends StatefulWidget {
  final int? wordbookId;
  final Map<String, int> hsvValues;

  const WordImageUploader({Key? key, this.wordbookId, required this.hsvValues})
      : super(key: key);

  @override
  State<WordImageUploader> createState() => _WordImageUploaderState();
}

class _WordImageUploaderState extends State<WordImageUploader> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return _uploading
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton.icon(
            icon: const Icon(Icons.image_search),
            label: const Text("이미지로 단어 추가"),
            onPressed: _openImageSourceSheet,
          );
  }

  Future<void> _openImageSourceSheet() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (kIsWeb || isDesktop) {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.single;
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 불러오지 못했습니다.')),
        );
        return;
      }
      await _uploadFlow(bytes, f.name);
      return;
    }

    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;

    final x = await _imagePicker.pickImage(
        source: src, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _uploadFlow(bytes, x.name);
  }

  Future<void> _uploadFlow(Uint8List bytes, String filename) async {
    setState(() => _uploading = true);
    try {
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 크기가 너무 큽니다(최대 8MB).')));
        return;
      }

      // 1️⃣ 이미지에서 단어 추출
      final words = await DjangoApi.uploadAndExtract(
        bytes: bytes,
        filename: filename,
        h: widget.hsvValues['h']!,
        s: widget.hsvValues['s']!,
        v: widget.hsvValues['v']!,
      );

      if (words.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('인식된 단어가 없습니다.')));
        return;
      }

      // 2️⃣ 단어 확인/편집
      final edited = await showReviewWordsSheet(context, initialWords: words);
      if (edited == null || edited.isEmpty) return;

      // 3️⃣ 의미 정의
      List<DefinitionItem> defs;
      try {
        defs = await DjangoApi.defineWords(edited);
      } catch (_) {
        defs = edited
            .map((w) =>
                DefinitionItem(word: w, meaning: '', pos: '', example: ''))
            .toList();
      }

      final confirmed = await showReviewMeaningsSheet(context, defs: defs);
      if (confirmed == null || confirmed.isEmpty) return;

      // 4️⃣ 서버(DB) 저장
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("jwt_token") ?? "";

      int addedCount = 0;
      final exist = <String>{}; // 기존 단어 확인용 (원래 리스트와 통합 필요)

      for (final m in confirmed) {
        final w = (m['word'] ?? '').trim();
        final mean = (m['meaning'] ?? '').trim();
        if (w.isEmpty || exist.contains(w.toLowerCase())) continue;
        exist.add(w.toLowerCase());

        final serverWordId = await _addWordToServer(w, mean);
        if (serverWordId != null) addedCount++;
      }

      if (addedCount > 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('단어장에 $addedCount개 추가됨')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<int?> _addWordToServer(String word, String meaning) async {
    if (widget.wordbookId == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token") ?? "";

    final url = Uri.parse("http://localhost:8080/api/v1/words");
    final body = jsonEncode({
      "wordEn": word,
      "wordKr": meaning,
      "meaning": meaning,
      "personalWordbookId": widget.wordbookId,
    });

    try {
      final res = await http.post(url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: body);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['personalWordbookWordId'] as int?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
