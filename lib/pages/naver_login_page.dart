import 'package:flutter/material.dart';
import 'mainMenuPage.dart';
import 'dart:html' as html;
import 'package:jwt_decoder/jwt_decoder.dart';

class NaverLoginPage extends StatefulWidget {
  const NaverLoginPage({super.key});

  @override
  State<NaverLoginPage> createState() => _NaverLoginPageState();
}

class _NaverLoginPageState extends State<NaverLoginPage> {
  @override
  void initState() {
    super.initState();
    _handleLogin();
  }

  Future<void> _handleLogin() async {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 토큰이 없습니다.')));
      }
      return;
    }

    // JWT 만료 체크
    if (JwtDecoder.isExpired(token)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('토큰이 만료되었습니다. 다시 로그인해주세요.')),
        );
      }
      return;
    }

    try {
      final decoded = JwtDecoder.decode(token);
      final userName = decoded['name'] ?? '사용자';

      if (mounted) {
        // ✅ 로그인 성공 SnackBar
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('환영합니다, $userName님!')));
      }

      // localStorage에 저장
      html.window.localStorage['naver_user_name'] = userName;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainMenuPage(userName: userName)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 토큰 처리 중 오류 발생')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
