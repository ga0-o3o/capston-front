// lib/services/api_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'http://192.168.0.12:8080'; // 스프링 IP:PORT

  static Future<String?> ping() async {
    final uri = Uri.parse('$baseUrl/api/ping');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return response.body;
    } else {
      return null;
    }
  }

  static Future<String?> echo(String name) async {
    final uri = Uri.parse('$baseUrl/api/echo');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      return null;
    }
  }
}
