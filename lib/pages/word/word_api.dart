import 'dart:convert';
import 'package:http/http.dart' as http;
import 'word_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordApi {
  // 개인 단어장 단어 조회
  static Future<List<WordItem>> fetchWords(int wordbookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final url =
          Uri.parse('http://localhost:8080/api/v1/wordbooks/$wordbookId/words');

      print('📡 [GET] 단어 조회 요청: $url');

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
          final wordIds = List<int>.from(e['wordIds'] ?? []);
          final isFavoriteRaw = e['favorite'];
          final isFavorite = isFavoriteRaw == true;

          return WordItem(
            personalWordbookWordId: wordIds.isNotEmpty ? wordIds.first : 0,
            word: wordEn,
            wordKr: wordKrList,
            favorite: isFavorite,
          );
        }).toList();
      } else {
        print('❌ 단어 조회 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ 단어 조회 오류: $e');
      return [];
    }
  }

  // 단어 즐겨찾기 토글
  static Future<bool> toggleFavorite(int personalWordbookId, int wordId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) throw Exception('로그인이 필요합니다.');

      final url = Uri.parse(
        'http://localhost:8080/api/words/$personalWordbookId/words/$wordId/toggle-favorite',
      );

      final response = await http.put(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('📡 [FAVORITE] 응답 코드: ${response.statusCode}');
      print('📡 [FAVORITE] 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ 즐겨찾기 상태 변경 성공');
        return true;
      } else {
        print('❌ 즐겨찾기 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 즐겨찾기 오류: $e');
      return false;
    }
  }

  // 단어 수정 1. 뜻 조회
  static Future<List<String>> fetchWordMeanings(String wordEn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      if (token.isEmpty) throw Exception('로그인이 필요합니다.');

      final url = Uri.parse('http://localhost:8080/api/words/$wordEn/meanings');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return List<String>.from(data['wordKr'] ?? []);
      } else {
        print('❌ 단어 뜻 조회 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ 단어 뜻 조회 오류: $e');
      return [];
    }
  }

  // 단어 수정 2. 그룹핑
  static Future<bool> updateWordGroup(
      int wordbookId, int wordId, List<String> newMeanings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      if (token.isEmpty) throw Exception('로그인이 필요합니다.');

      final url =
          Uri.parse('http://localhost:8080/api/words/$wordbookId/words/group');

      final body = jsonEncode({
        'wordIds': [wordId],
        'wordKrList': newMeanings, // 선택한 뜻 보내기
      });

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        print('✅ 단어 그룹핑 수정 성공: ${response.body}');
        return true;
      } else {
        print('❌ 단어 그룹핑 수정 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 단어 그룹핑 수정 오류: $e');
      return false;
    }
  }

  // 단어 삭제
  static Future<bool> deleteWord(int wordbookId, int wordId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = Uri.parse(
        'http://localhost:8080/api/words/personal-wordbooks/$wordbookId/words/$wordId',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        print('✅ 단어 삭제 성공: ${jsonDecode(response.body)['message']}');
        return true;
      } else {
        print('❌ 단어 삭제 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 단어 삭제 오류: $e');
      return false;
    }
  }
}
