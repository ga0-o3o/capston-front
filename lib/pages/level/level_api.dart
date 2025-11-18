// lib/pages/level/level_api.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ✅ ApiService import 추가
import '../../api_service.dart';

/// Level Test API Service
///
/// ⚠️ 중요: FastAPI URL은 ApiService.fastApiUrl을 사용합니다!
///         레벨 테스트는 Spring Boot가 아닌 FastAPI에서 처리됩니다.
class LevelTestApi {
  // ✅ FastAPI server URL - ApiService에서 가져오기
  static String get baseUrl => ApiService.fastApiUrl;

  // -----------------------------------------------------------
  // Common functions
  // -----------------------------------------------------------

  /// Get JWT token from SharedPreferences
  static Future<String?> _getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Create headers with JWT token
  static Map<String, String> _headersWithAuth(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  // -----------------------------------------------------------
  // API request functions
  // -----------------------------------------------------------

  /// 1. Start level test
  /// GET ${SERVER_URL}/api/test
  /// Response: { "message": "Level test started", "firstQuestion": "..." }
  static Future<LevelTestStartResponse> startLevelTest() async {
    try {
      final token = await _getJwtToken();
      final uri = Uri.parse('$baseUrl/api/test');

      print('[API] Sending request to: $uri');
      print('[API] Token: ${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NOT FOUND"}');

      final response = await http
          .get(uri, headers: _headersWithAuth(token))
          .timeout(const Duration(seconds: 30));

      print('[API] Response status: ${response.statusCode}');
      print('[API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return LevelTestStartResponse.fromJson(data);
      } else {
        throw Exception(
            'Failed to start level test: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw Exception('Network connection error. Please check your connection.');
    } on HttpException {
      throw Exception('HTTP communication error occurred.');
    } on FormatException {
      throw Exception('Cannot parse server response.');
    }
  }

  /// 2. Restart level test (reset turn number)
  /// DELETE ${SERVER_URL}/api/test
  /// Response: { "message": "...", "success": true }
  static Future<void> restartLevelTest() async {
    try {
      final token = await _getJwtToken();
      final uri = Uri.parse('$baseUrl/api/test');

      print('[API] Restarting level test: $uri');

      final response = await http
          .delete(uri, headers: _headersWithAuth(token))
          .timeout(const Duration(seconds: 30));

      print('[API] Restart response status: ${response.statusCode}');
      print('[API] Restart response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          print('[API] Level test restarted successfully');
        } else {
          throw Exception('Restart failed: ${data['message']}');
        }
      } else {
        throw Exception(
            'Failed to restart level test: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw Exception('Network connection error. Please check your connection.');
    } on HttpException {
      throw Exception('HTTP communication error occurred.');
    } on FormatException {
      throw Exception('Cannot parse server response.');
    }
  }

  /// 3. Send user answer and get next question
  /// POST ${SERVER_URL}/api/test
  /// Request: { "message": "..." }
  /// Response: { "response": "...", "isFinished": false }
  static Future<LevelTestAnswerResponse> sendAnswer(String answer) async {
    try {
      final token = await _getJwtToken();
      final uri = Uri.parse('$baseUrl/api/test');

      print('[API] Sending answer to: $uri');
      print('[API] Message: ${answer.substring(0, answer.length > 50 ? 50 : answer.length)}...');

      final response = await http
          .post(
            uri,
            headers: _headersWithAuth(token),
            body: jsonEncode({'message': answer}),
          )
          .timeout(const Duration(seconds: 120));  // 10번째 턴 레벨 평가 대비 timeout 증가

      print('[API] Response status: ${response.statusCode}');
      print('[API] Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          print('[API] Response parsed successfully');
          print('[API] Level display: ${data['level_display']}');
          print('[API] Dialog num: ${data['dialog_num']}');
          return LevelTestAnswerResponse.fromJson(data);
        } catch (e) {
          print('[ERROR] JSON parsing failed: $e');
          print('[ERROR] Response body: ${response.body}');
          throw Exception('Failed to parse response: $e');
        }
      } else {
        print('[ERROR] HTTP ${response.statusCode}');
        print('[ERROR] Body: ${response.body}');
        throw Exception(
            'Failed to send answer: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('[ERROR] Request timeout: $e');
      throw Exception('Request timeout. Server may be processing level evaluation.');
    } on SocketException catch (e) {
      print('[ERROR] Network error: $e');
      throw Exception('Network connection error. Please check your connection.');
    } on HttpException catch (e) {
      print('[ERROR] HTTP error: $e');
      throw Exception('HTTP communication error occurred.');
    } on FormatException catch (e) {
      print('[ERROR] Format error: $e');
      throw Exception('Cannot parse server response.');
    } catch (e) {
      print('[ERROR] Unexpected error: $e');
      throw Exception('Unexpected error: $e');
    }
  }

}

// -----------------------------------------------------------
// Data model classes
// -----------------------------------------------------------

/// Level test start response
class LevelTestStartResponse {
  final String response;

  String get firstQuestion => response;
  String get message => response;

  LevelTestStartResponse({
    required this.response,
  });

  factory LevelTestStartResponse.fromJson(Map<String, dynamic> json) {
    return LevelTestStartResponse(
      response: json['response'] ?? 'Level test started. Please introduce yourself.',
    );
  }
}

/// Answer submission response
class LevelTestAnswerResponse {
  final String levelDisplay;
  final String currentLevel;
  final bool levelChanged;
  final String evaluatedLevel;
  final int dialogNum;
  final int levelTestNum;
  final String llmReply;
  final String userMessage;

  String? get nextQuestion => llmReply;
  bool get isFinished => dialogNum >= 100;

  LevelTestAnswerResponse({
    required this.levelDisplay,
    required this.currentLevel,
    required this.levelChanged,
    required this.evaluatedLevel,
    required this.dialogNum,
    required this.levelTestNum,
    required this.llmReply,
    required this.userMessage,
  });

  factory LevelTestAnswerResponse.fromJson(Map<String, dynamic> json) {
    return LevelTestAnswerResponse(
      levelDisplay: json['level_display'] ?? 'Your Level: Beginner',
      currentLevel: json['current_level'] ?? 'Beginner',
      levelChanged: json['level_changed'] ?? false,
      evaluatedLevel: json['evaluated_level'] ?? '',
      dialogNum: json['dialog_num'] ?? 0,
      levelTestNum: json['level_test_num'] ?? 1,
      llmReply: json['llm_reply'] ?? '',
      userMessage: json['user_message'] ?? '',
    );
  }
}
