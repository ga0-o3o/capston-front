import 'dart:convert';
import 'package:http/http.dart' as http;
import 'word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordApi {
  /// 단어 조회
  static Future<List<WordItem>> fetchWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final savedWordbookId = prefs.getInt('selectedWordbookId');

      if (token.isEmpty || savedWordbookId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = Uri.parse(
          'http://localhost:8080/api/v1/wordbooks/$savedWordbookId/words');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;

        return data.map((e) {
          final wordEn = e['wordEn'] ?? '';
          final wordKrList = List<String>.from(e['wordKr'] ?? []);
          return WordItem(
            personalWordbookWordId: e['personalWordbookWordId'] ?? 0,
            word: wordEn,
            wordKr: wordKrList,
            favorite: e['favorite'] ?? false,
          );
        }).toList();
      } else {
        print('단어 조회 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('단어 조회 오류: $e');
      return [];
    }
  }

  /// 단어 즐겨찾기 토글
  static Future<bool> toggleFavorite(int personalWordbookWordId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final savedWordbookId = prefs.getInt('selectedWordbookId');

      if (token.isEmpty || savedWordbookId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = Uri.parse(
          'http://localhost:8080/api/words/$savedWordbookId/words/$personalWordbookWordId/toggle-favorite');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true; // 성공
      } else {
        print('즐겨찾기 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('즐겨찾기 오류: $e');
      return false;
    }
  }

  /// 단어 삭제
  static Future<void> deleteWord(int wordbookId, int wordId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = Uri.parse(
        'http://localhost:8080/api/words/personal-wordbook/$wordbookId/words/$wordId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('단어 삭제 실패');
    }
  }
}
