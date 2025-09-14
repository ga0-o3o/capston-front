// lib/services/django_api.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/definition_item.dart';
import '../models/word_item.dart';

class DjangoApi {
  // 필요 시 --dart-define=API_BASE=http://10.0.2.2:8500 등으로 재정의
  static const String _base =
      String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8500');

  static const String _uploadPath = '/api/upload_edit/';
  static const String _definePath = '/api/define_words/';
  static const String _wordsPath = '/api/words/';

  // ---------- helpers ----------
  static MediaType? guessMediaType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return MediaType('image', 'png');
    if (n.endsWith('.jpg') || n.endsWith('.jpeg'))
      return MediaType('image', 'jpeg');
    if (n.endsWith('.gif')) return MediaType('image', 'gif');
    if (n.endsWith('.webp')) return MediaType('image', 'webp');
    return null;
  }

  static Future<http.Response> _jsonPost(Uri uri, Object body,
          {int sec = 20}) =>
      http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(Duration(seconds: sec));

  // ---------- image upload + OCR ----------
  static Future<List<String>> uploadAndExtract({
    required Uint8List bytes,
    required String filename,
    required int h,
    required int s,
    required int v,
  }) async {
    final mt = guessMediaType(filename);
    if (mt == null) {
      throw Exception('지원하지 않는 이미지 형식입니다.');
    }

    final uri = Uri.parse('$_base$_uploadPath');
    final req = http.MultipartRequest('POST', uri)
      ..fields['h'] = h.toString()
      ..fields['s'] = s.toString()
      ..fields['v'] = v.toString()
      ..files.add(http.MultipartFile.fromBytes('image', bytes,
          filename: filename, contentType: mt));

    final streamed = await req.send().timeout(const Duration(seconds: 20));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('업로드 실패 (${resp.statusCode}) ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final words = (data['words'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    return words;
  }

  // ---------- definitions via Django(OpenAI) ----------
  static Future<List<DefinitionItem>> defineWords(List<String> words) async {
    final uri = Uri.parse('$_base$_definePath');
    final res = await _jsonPost(uri, {'words': words});

    if (res.statusCode != 200) {
      throw Exception('정의 조회 실패: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data['items'] as List?) ?? const [];
    return items
        .map((e) => DefinitionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- words persistence ----------
  /// 전체 단어 조회
  static Future<List<WordItem>> fetchWords() async {
    final uri = Uri.parse('$_base$_wordsPath');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('단어 조회 실패: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data['items'] as List?) ?? const [];
    return items
        .map((e) => WordItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 여러 단어 저장/병합
  static Future<List<WordItem>> saveWords(List<WordItem> items) async {
    final uri = Uri.parse('$_base$_wordsPath');
    final body = {
      'items':
          items.map((e) => {'word': e.word, 'meaning': e.meaning}).toList(),
    };
    final res = await _jsonPost(uri, body, sec: 20);
    if (res.statusCode != 200) {
      throw Exception('단어 저장 실패: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    final out = (data['items'] as List?) ?? const [];
    return out
        .map((e) => WordItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 단어 수정(즐겨찾기/뜻/단어명)
  static Future<WordItem> patchWord(WordItem it) async {
    if (it.id == null) throw Exception('id 없음');
    final uri = Uri.parse('$_base$_wordsPath${it.id!}/');
    final res = await http
        .patch(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'favorite': it.favorite,
              'meaning': it.meaning,
              'word': it.word
            }))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('단어 수정 실패: ${res.statusCode} ${res.body}');
    }
    return WordItem.fromJson(jsonDecode(res.body));
  }

  /// 단어 삭제
  static Future<void> deleteWord(int id) async {
    final uri = Uri.parse('$_base$_wordsPath$id/');
    final res = await http.delete(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('삭제 실패: ${res.statusCode} ${res.body}');
    }
  }
}
