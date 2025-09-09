import 'package:flutter/material.dart';
import 'mainMenuPage.dart';

class UserInfoPage extends StatelessWidget {
  final String userName;

  const UserInfoPage({Key? key, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 정보'),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Center(
        child: Text(
          '안녕하세요, $userName 님!',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
