import 'dart:convert';
import 'package:http/http.dart' as http;
import 'word_item.dart';
import 'word_meaning.dart';
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

      final url = Uri.parse(
          'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/wordbooks/$wordbookId/words');

      print('📡 [GET] 단어 조회 요청: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
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
          final isFavoriteRaw = e['favorite'];
          final isFavorite = isFavoriteRaw == true;

          final personalWordbookId = e['personalWordbookId'] ?? wordbookId;

          return WordItem(
            personalWordbookWordId: wordIds.isNotEmpty ? wordIds.first : 0,
            personalWordbookId: personalWordbookId,
            word: wordEn,
            wordKr: wordKrList,
            favorite: isFavorite,
            groupWordIds: wordIds,
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
        'https://semiconical-shela-loftily.ngrok-free.dev/api/words/$personalWordbookId/words/$wordId/toggle-favorite',
      );

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
        },
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
  static Future<List<WordMeaning>> fetchWordMeanings(String wordEn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      if (token.isEmpty) throw Exception('로그인이 필요합니다.');

      final url = Uri.parse(
          'https://semiconical-shela-loftily.ngrok-free.dev/api/words/$wordEn/meanings');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final wordMeanings = (data['wordMeanings'] as List)
            .map((e) => WordMeaning(
                  wordId: e['wordId'],
                  wordKr: e['wordKr'],
                ))
            .toList();
        return wordMeanings;
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
      int wordbookId, String wordEn, List<int> wordIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        print('❌ 토큰이 없습니다. 로그인 후 다시 시도하세요.');
        return false;
      }

      final uri = Uri.parse(
          'https://semiconical-shela-loftily.ngrok-free.dev/api/words/$wordbookId/words/$wordEn');

      final body = jsonEncode({'wordIds': wordIds});

      print('📤 단어 수정 요청: PUT $uri');
      print('📦 요청 바디: $body');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      print('📥 응답 코드: ${response.statusCode}');
      print('📥 응답 바디: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ 단어 수정 중 오류 발생: $e');
      return false;
    }
  }

  // 단어 병합
  static Future<bool> mergeWords(int wordbookId, List<int> wordIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final url = Uri.parse(
          'https://semiconical-shela-loftily.ngrok-free.dev/api/words/$wordbookId/words/merge');

      print('📡 [PUT] 단어 병합 요청: $url');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'wordIds': wordIds}),
      );

      if (response.statusCode == 200) {
        print('✅ 단어 병합 완료: ${response.body}');
        return true; // 성공 여부만 반환
      } else {
        print('❌ 단어 병합 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 단어 병합 오류: $e');
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
        'https://semiconical-shela-loftily.ngrok-free.dev/api/words/personal-wordbooks/$wordbookId/words/$wordId',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
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

  // 퀴즈 기록
  static Future<bool> recordQuiz({
    required int personalWordbookId,
    required int wordId,
    required bool isWrong,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      if (token.isEmpty) throw Exception('로그인이 필요합니다.');

      // URL Path 변수로 전달
      final url = Uri.parse(
        'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/quiz/$personalWordbookId/words/$wordId/record/$isWrong',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('퀴즈 기록 저장 성공: ${response.body}');
        return true;
      } else {
        print('퀴즈 기록 저장 실패: ${response.statusCode}, ${response.body}');
        return false;
      }
    } catch (e) {
      print('퀴즈 기록 저장 오류: $e');
      return false;
    }
  }

  // 영작 문법 검사
  static Future<List<Issue>> checkGrammar(String sentence) async {
    final url = Uri.parse("https://api.sapling.ai/api/v1/edits");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer N2QEVVE9CQYMDDD87XQ0A0LCB14GKFXB",
        },
        body: jsonEncode({
          "text": sentence,
          "session_id": "quiz_session_1",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final edits = data["edits"] as List;

        return edits.map<Issue>((e) {
          final wrongText = sentence.substring(
            e["start"] as int,
            (e["end"] as int).clamp(0, sentence.length),
          );

          final replacement = (e["replacements"] as List?)?.isNotEmpty == true
              ? e["replacements"][0]
              : "Error";

          return Issue(wrongText, replacement);
        }).toList();
      } else {
        return [Issue('', "문법 검사 실패: ${response.statusCode}")];
      }
    } catch (e) {
      return [Issue('', "문법 검사 오류: $e")];
    }
  }

  static const String baseUrl =
      "https://semiconical-shela-loftily.ngrok-free.dev";

  static Future<List<String>> checkQuiz(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

<<<<<<< HEAD
    if (token.isEmpty) {
      throw Exception('로그인이 필요합니다.');
=======
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': '69420',
        'Ngrok-Skip-Browser-Warning': '69420',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      body: jsonEncode(data),
    );

    print('📡 checkQuiz status: ${resp.statusCode}');
    print('📡 checkQuiz body: ${resp.body}');
    print('📡 checkQuiz url: $uri');

    if (resp.statusCode != 200) {
      throw Exception('정답 확인 실패: ${resp.body}');
>>>>>>> 6f5da5361a234f979c0b8e48c7f9f652ab8ebd2a
    }

    final uri = Uri.parse("$baseUrl/api/v1/quiz/answers?word=$word");

    final resp = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    print("📡 checkQuiz status: ${resp.statusCode}");
    print("📡 checkQuiz body: ${resp.body}");
    print("📡 checkQuiz url: $uri");

    if (resp.statusCode != 200) {
      throw Exception("정답 뜻 조회 실패: ${resp.body}");
    }

    final data = jsonDecode(resp.body);

    // 🔥 핵심: wordKr 리스트를 반드시 List<String>으로 변환해서 반환
    final List<String> meanings = List<String>.from(data["wordKr"] ?? []);

    return meanings;
  }
}
