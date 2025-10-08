import 'dart:convert';
import 'package:http/http.dart' as http;
import '../word/word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewApi {
  /// 오늘 복습할 단어 조회
  static Future<List<WordItem>> fetchReviewWords(String loginId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = Uri.parse(
          'http://localhost:8080/api/v1/wordbooks/$loginId/review-words');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);

      // WordItem으로 변환
      return data.map((item) {
        return WordItem(
          personalWordbookWordId:
              (item['wordIds'] != null && item['wordIds'].isNotEmpty)
                  ? item['wordIds'][0]
                  : 0,
          personalWordbookId: 0, // 임시 값, 실제 서버 wordbookId가 있다면 넣기
          word: item['wordEn'] ?? '',
          wordKr: List<String>.from(item['wordKr'] ?? []),
          wordKrOriginal: List<String>.from(item['wordKr'] ?? []),
          groupWordIds: List<int>.from(item['wordIds'] ?? []),
          favorite: item['favorite'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('❌ fetchReviewWords 에러: $e');
      return [];
    }
  }
}
