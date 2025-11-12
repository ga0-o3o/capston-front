import 'dart:convert';
import 'package:http/http.dart' as http;
import '../word/word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameApi {
  /// 사용자의 모든 단어 조회
  static Future<List<WordItem>> fetchAllWords(String loginId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = Uri.parse(
        'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/wordbooks/$loginId/all-words');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;

      return data.map((e) {
        final wordEn = e['wordEn'] ?? '';
        final wordKrList = List<String>.from(e['wordKr'] ?? []);
        final wordIds = List<int>.from(e['wordIds'] ?? []);

        // 단어장 ID 없으면 0
        final personalWordbookId = e['personalWordbookId'] ?? 0;

        return WordItem(
          personalWordbookWordId: wordIds.isNotEmpty ? wordIds.first : 0,
          personalWordbookId: personalWordbookId,
          word: wordEn,
          wordKr: wordKrList,
          favorite: e['favorite'] ?? false,
        );
      }).toList();
    } else {
      throw Exception('단어 조회 실패: ${response.statusCode}');
    }
  }
}
