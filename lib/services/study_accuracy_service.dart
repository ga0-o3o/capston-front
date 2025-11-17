import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 학습 정확도 데이터 모델
class StudyAccuracyRecord {
  final DateTime date;
  final double accuracy; // 0-100%

  StudyAccuracyRecord({
    required this.date,
    required this.accuracy,
  });

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  /// JSON에서 생성
  factory StudyAccuracyRecord.fromJson(Map<String, dynamic> json) {
    return StudyAccuracyRecord(
      date: DateTime.parse(json['date']),
      accuracy: (json['accuracy'] as num).toDouble(),
    );
  }

  /// 날짜만 비교 (시간 제외)
  String get dateKey {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 학습 정확도 기록 관리 서비스
class StudyAccuracyService {
  static const String _storageKey = 'study_accuracy_history';

  /// 학습 정확도 기록 추가
  /// 같은 날짜에 여러 번 학습한 경우 평균을 계산
  static Future<void> addRecord({
    required int correctCount,
    required int totalCount,
  }) async {
    if (totalCount == 0) {
      print('[STUDY_ACCURACY] Total count is 0, skipping record');
      return;
    }

    final accuracy = (correctCount / totalCount) * 100;
    final today = DateTime.now();

    print('[STUDY_ACCURACY] Adding record: $correctCount/$totalCount = ${accuracy.toStringAsFixed(1)}%');

    final prefs = await SharedPreferences.getInstance();
    final records = await _loadRecords();

    // 오늘 날짜의 기록이 있는지 확인
    final todayKey = _dateKey(today);
    final existingRecordIndex = records.indexWhere(
      (record) => record.dateKey == todayKey,
    );

    if (existingRecordIndex != -1) {
      // 오늘 이미 기록이 있으면 평균 계산
      final existingRecord = records[existingRecordIndex];
      final newAccuracy = (existingRecord.accuracy + accuracy) / 2;

      print('[STUDY_ACCURACY] Today\'s record already exists, averaging: ${existingRecord.accuracy.toStringAsFixed(1)}% -> ${newAccuracy.toStringAsFixed(1)}%');

      records[existingRecordIndex] = StudyAccuracyRecord(
        date: today,
        accuracy: newAccuracy,
      );
    } else {
      // 새로운 날짜 기록 추가
      records.add(StudyAccuracyRecord(
        date: today,
        accuracy: accuracy,
      ));
      print('[STUDY_ACCURACY] New record added for $todayKey');
    }

    // 날짜 순으로 정렬
    records.sort((a, b) => a.date.compareTo(b.date));

    // 저장
    await _saveRecords(records);
    print('[STUDY_ACCURACY] Saved ${records.length} records');
  }

  /// 모든 기록 불러오기
  static Future<List<StudyAccuracyRecord>> loadRecords() async {
    final records = await _loadRecords();
    print('[STUDY_ACCURACY] Loaded ${records.length} records');
    return records;
  }

  /// 최근 N일 기록 불러오기
  static Future<List<StudyAccuracyRecord>> loadRecentRecords(int days) async {
    final allRecords = await _loadRecords();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final recentRecords = allRecords
        .where((record) => record.date.isAfter(cutoffDate))
        .toList();

    print('[STUDY_ACCURACY] Loaded ${recentRecords.length} records from last $days days');
    return recentRecords;
  }

  /// 평균 정확도 계산
  static Future<double> getAverageAccuracy() async {
    final records = await _loadRecords();
    if (records.isEmpty) return 0.0;

    final sum = records.fold<double>(0, (prev, record) => prev + record.accuracy);
    final average = sum / records.length;

    print('[STUDY_ACCURACY] Average accuracy: ${average.toStringAsFixed(1)}%');
    return average;
  }

  /// 모든 기록 삭제 (테스트용)
  static Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    print('[STUDY_ACCURACY] All records cleared');
  }

  // ===================================================================
  // Private helper methods
  // ===================================================================

  /// SharedPreferences에서 기록 불러오기
  static Future<List<StudyAccuracyRecord>> _loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => StudyAccuracyRecord.fromJson(item))
          .toList();
    } catch (e) {
      print('[ERROR] Failed to load study accuracy records: $e');
      return [];
    }
  }

  /// SharedPreferences에 기록 저장
  static Future<void> _saveRecords(List<StudyAccuracyRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(records.map((r) => r.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('[ERROR] Failed to save study accuracy records: $e');
    }
  }

  /// 날짜 키 생성 (YYYY-MM-DD)
  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
