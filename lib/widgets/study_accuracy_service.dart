// lib/services/study_accuracy_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 하루 학습 기록 (날짜 + 학습한 단어 개수)
class StudyAccuracyRecord {
  final DateTime date;
  final int count;

  StudyAccuracyRecord({
    required this.date,
    required this.count,
  });

  factory StudyAccuracyRecord.fromJson(Map<String, dynamic> json) {
    return StudyAccuracyRecord(
      date: DateTime.parse(json['date'] as String),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudyAccuracyService {
  static const String _baseUrl =
      'https://semiconical-shela-loftily.ngrok-free.dev';

  /// 최근 n일 기록 불러오기
  static Future<List<StudyAccuracyRecord>> loadRecentRecords(int days) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('jwt_token');

    if (userId == null || userId.isEmpty) {
      print('[STUDY_ACCURACY] ⚠️ user_id 없음. 로그인 먼저 필요');
      return [];
    }

    final uri = Uri.parse(
      '$_baseUrl/api/words/learning-history?userId=$userId',
    );
    print('[STUDY_ACCURACY] 🔍 요청: $uri');

    // 기본 헤더
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',

      // ngrok 경고 우회
      'ngrok-skip-browser-warning': '69420',
      'Ngrok-Skip-Browser-Warning': '69420',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };

    // JWT 있으면 Authorization 추가
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final resp = await http.get(uri, headers: headers);

      print('[STUDY_ACCURACY] Status: ${resp.statusCode}');
      print('[STUDY_ACCURACY] Raw Body (first 200 chars): '
          '${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}');

      // 200 아닐 때는 그냥 빈 리스트 리턴 (차트에서 에러 안 터지게)
      if (resp.statusCode != 200) {
        print('[STUDY_ACCURACY] ❌ 비정상 응답 코드: ${resp.statusCode}');
        return [];
      }

      // HTML이 섞여온 경우 방어
      if (resp.body.trim().startsWith('<')) {
        print('[STUDY_ACCURACY] ❌ HTML 응답 감지. JSON 아님');
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(resp.body);

      final records = jsonList
          .map((e) => StudyAccuracyRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      print('[STUDY_ACCURACY] ✅ Parsed ${records.length} records');

      // 혹시 서버가 7일보다 많이 줄 수 있으니 뒤쪽 days개만 사용
      if (records.length > days) {
        return records.sublist(records.length - days);
      }
      return records;
    } catch (e) {
      print('[STUDY_ACCURACY] ❌ 예외 발생: $e');
      return [];
    }
  }
}
