import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WordbookService {
  // 단어장 목록 가져오기
  static Future<List<Map<String, dynamic>>> fetchWordbooks(
      BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getString('user_id') ?? "";

    if (userId.isEmpty || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다.')),
      );
      return [];
    }

    final url = Uri.parse(
        'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/wordbooks/user/$userId');

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
      'Content-Type': 'application/json',
    });

    print('🌐 요청 전송: ${url.toString()} / token: ${token.substring(0, 10)}...');

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final list = data['wordbooks'] as List<dynamic>;

      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장이 존재하지 않습니다.')),
        );
        return [];
      }

      return list.map((e) {
        final id = e['personalWordbookId'] ?? 1;
        final imageIndex = (id % 3) + 1;
        return {
          'title': e['title'] ?? '제목 없음',
          'id': id,
          'color': Colors.primaries[id % Colors.primaries.length],
          'image': 'assets/images/wordBook$imageIndex.png',
        };
      }).toList();
    } else if (res.statusCode == 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장이 존재하지 않습니다.')),
      );
      return [];
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장 목록을 불러오지 못했습니다.')),
      );
      return [];
    }
  }

  // 단어장 추가
  static Future<Map<String, dynamic>?> addWordbook(
      String title, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final loginId = prefs.getString('user_id');

    if (loginId == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다.')),
      );
      return null;
    }

    final url = Uri.parse(
        'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/wordbooks');
    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
      },
      body: json.encode({'loginId': loginId, 'title': title}),
    );

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장 추가에 실패했습니다.')),
      );
      return null;
    }
  }

  // 단어장 이름 수정
  static Future<bool> editWordbook(
      int id, String title, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final url = Uri.parse(
        'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/wordbooks');
    final res = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
      },
      body: json.encode({'personalWordbookId': id, 'title': title}),
    );

    return res.statusCode == 200;
  }

  // 단어장 삭제
  static Future<bool> deleteWordbook(int id, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = Uri.parse(
          'https://semiconical-shela-loftily.ngrok-free.dev/api/v1/wordbooks/$id');
      final res = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        // 성공 메시지 출력 (선택)
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? '삭제 완료')),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장 삭제 실패')),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
      return false;
    }
  }
}
