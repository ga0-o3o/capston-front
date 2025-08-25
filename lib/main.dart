import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'pages/before_page.dart';
import 'pages/mainMenuPage.dart';
import 'pages/naver_login_page.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: '9da25abebbee7a0c2b346f01bbbe9a32',
    javaScriptAppKey: 'b867d8e54f51ac5b0d1d08f7a5d25bca',
  );

  String? initialUserName;

  if (kIsWeb) {
    final uri = Uri.parse(html.window.location.href);
    final token = uri.queryParameters['token'];

    if (token != null && token.isNotEmpty) {
      // 토큰 만료 체크
      if (!JwtDecoder.isExpired(token)) {
        try {
          final decoded = JwtDecoder.decode(token);
          initialUserName = decoded['name']?.toString() ?? '사용자';
          html.window.localStorage['naver_user_name'] = initialUserName;
        } catch (e) {
          // 토큰 파싱 오류
          initialUserName = null;
        }
      } else {
        // 토큰 만료 시 localStorage 삭제
        html.window.localStorage.remove('naver_user_name');
        initialUserName = null;
      }
    }
  }

  runApp(MyApp(initialUserName: initialUserName));
}

class MyApp extends StatelessWidget {
  final String? initialUserName;

  const MyApp({super.key, this.initialUserName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단어 공부 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF6F0E9),
      ),
      home:
          initialUserName != null
              ? MainMenuPage(userName: initialUserName!)
              : const BeforePage(),
      routes: {'/naver-login': (context) => const NaverLoginPage()},
    );
  }
}
