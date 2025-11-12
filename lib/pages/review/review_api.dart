import 'dart:convert';
import 'package:http/http.dart' as http;
import '../word/word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewApi {
  // 오늘 복습할 단어 조회
  static Future<List<WordItem>> fetchReviewWords(String loginId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = Uri.parse(
          'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/wordbooks/$loginId/review-words');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      print('📡 서버 응답 바디: $decoded'); // ✅ 구조 확인용 로그

      // ✅ data 키가 없을 수도 있고, 전체가 리스트일 수도 있음
      final List<dynamic> data =
          decoded is List ? decoded : (decoded['data'] ?? []);

      return data.map((item) {
        return WordItem(
          personalWordbookWordId:
              (item['wordIds'] != null && item['wordIds'].isNotEmpty)
                  ? item['wordIds'][0]
                  : 0,
          personalWordbookId: item['personalWordbookId'] ?? 0,
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

  /// 복습일 업데이트
  static Future<bool> updateReviewDate(
      int personalWordbookId, int wordId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return false;

    final url = Uri.parse(
        'https://semiconical-shela-loftily.ngrok-free.dev/api/words/review/$personalWordbookId/$wordId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // body: "복습일 업데이트 성공"
        return true;
      } else {
        print('복습일 업데이트 실패: ${response.statusCode} / ${response.body}');
        return false;
      }
    } catch (e) {
      print('복습일 업데이트 예외: $e');
      return false;
    }
  }
}
