import 'package:flutter/material.dart';

class MultiplayerGamePage extends StatelessWidget {
  final List<String> userIds;

  const MultiplayerGamePage({Key? key, required this.userIds})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("멀티플레이 게임")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("참가 플레이어: ${userIds.join(", ")}"),
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
