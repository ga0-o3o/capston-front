import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'animated_button.dart';
import 'login_service.dart';
import '../mainMenuPage.dart';
import '../loading_page.dart';
import '../signup_page.dart' hide AnimatedButton;

class SNSLogin extends StatefulWidget {
  const SNSLogin({super.key});

  @override
  State<SNSLogin> createState() => _SNSLoginState();
}

class _SNSLoginState extends State<SNSLogin> {
  String? _errorMessage;

  Future<void> _loginWithKakao() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoadingPage()),
    );
    try {
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token = isInstalled
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      User kakaoUser = await UserApi.instance.me();
      final kakaoId = kakaoUser.id.toString();
      final kakaoName = kakaoUser.kakaoAccount?.profile?.nickname ?? "사용자";

      final data = await LoginService.loginWithKakao(kakaoId, kakaoName);
      Navigator.pop(context);

      if (data != null) {
        await LoginService.saveToken(data['token']);
        await LoginService.saveUserInfo(
          id: data['loginId'],
          name: data['name'],
          nickname: data['nickname'],
          rank: data['userRank'] ?? 'Beginner',
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => MainMenuPage(userName: data['nickname'])),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      setState(() => _errorMessage = '카카오 로그인 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('-- SNS 계정으로 로그인 --',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        AnimatedButton(
          text: '카카오톡 로그인',
          icon: Image.asset('assets/images/kakao_logo.png',
              height: 24, width: 24),
          backgroundColor: const Color(0xFFFFE812),
          foregroundColor: Colors.black,
          onPressed: _loginWithKakao,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SignupPage())),
          child: const Text('회원가입', style: TextStyle(color: Color(0xFF1F3551))),
        ),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      ],
    );
  }
}
