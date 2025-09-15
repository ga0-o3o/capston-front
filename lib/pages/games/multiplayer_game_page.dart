import 'package:flutter/material.dart';

class MultiplayerGamePage extends StatelessWidget {
  final List<String> userIds;

  const MultiplayerGamePage({Key? key, required this.userIds})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("단어 빨리 맞히기 (멀티)"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("멀티플레이어 게임 화면"),
            const SizedBox(height: 16),
            Text("플레이어: ${userIds.join(", ")}"),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("뒤로가기"),
            ),
          ],
        ),
      ),
    );
  }
}
