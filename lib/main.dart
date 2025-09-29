import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'pages/before_page.dart';
import 'pages/mainMenuPage.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: '9da25abebbee7a0c2b346f01bbbe9a32',
    javaScriptAppKey: 'b867d8e54f51ac5b0d1d08f7a5d25bca',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ✅ 앱 전체 Text 위젯 기본 폰트 변경
        textTheme: GoogleFonts.nunitoTextTheme(), // 원하는 폰트로 변경
      ),
      home: const BeforePage(),
    );
  }
}
