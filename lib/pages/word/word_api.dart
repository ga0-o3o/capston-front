// lib/api/word_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordApi {
  static Future<void> deleteWord(int wordbookId, int wordId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = Uri.parse(
        'http://localhost:8080/api/words/personal-wordbook/$wordbookId/$wordId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('단어 삭제 실패');
    }
  }
}
