// lib/services/upload_flow.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../models/definition_item.dart';
import 'django_api.dart';
import '../widgets/review_words_sheet.dart';
import '../widgets/review_meanings_sheet.dart';

/// 업로드 → OCR → 1차수정 → 정의조회 → 2차수정 → 서버저장 → 저장된 WordItem 반환
Future<List<WordItem>> runUploadFlow(
  BuildContext context, {
  required Uint8List bytes,
  required String filename,
  required int h,
  required int s,
  required int v,
}) async {
  // 1) 업로드+OCR
  final words = await DjangoApi.uploadAndExtract(
    bytes: bytes, filename: filename, h: h, s: s, v: v,
  );
  if (words.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인식된 단어가 없습니다.')),
    );
    return [];
  }

  // 2) 1차 검토/수정
  final edited = await showReviewWordsSheet(context, initialWords: words);
  if (edited == null || edited.isEmpty) return [];

  // 3) 정의 조회(백엔드 → OpenAI)
  List<DefinitionItem> defs;
  try {
    defs = await DjangoApi.defineWords(edited);
  } catch (_) {
    defs = edited.map((w) => DefinitionItem(word: w, meaning: '', pos: '', example: '')).toList();
  }

  // 4) 2차 검토(뜻/품사/예문) → 서버 저장
  final confirmed = await showReviewMeaningsSheet(context, defs: defs);
  if (confirmed == null || confirmed.isEmpty) return [];

  final toSave = confirmed
      .map((m) => WordItem(word: (m['word'] ?? '').trim(), meaning: (m['meaning'] ?? '').trim()))
      .where((w) => w.word.isNotEmpty)
      .toList();

  final saved = await DjangoApi.saveWords(toSave); // id 포함
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('단어장에 ${saved.length}개 추가')),
  );
  return saved;
}
