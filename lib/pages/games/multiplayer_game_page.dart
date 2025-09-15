import 'package:flutter/material.dart';
import 'game1_page.dart';
import 'game2_multi_page.dart';
import 'game4_multi_page.dart';
import 'game5_multi_page.dart';
import 'game6_multi_page.dart';

import 'matching_page.dart';
import '../game_menu_page.dart';

class MultiplayerGamePage extends StatefulWidget {
  final List<String> userIds;
  final String hostToken;
  final String gameId; // 추가

  const MultiplayerGamePage({
    Key? key,
    required this.userIds,
    required this.hostToken,
    required this.gameId,
  }) : super(key: key);

  @override
  State<MultiplayerGamePage> createState() => _MultiplayerGamePageState();
}

class _MultiplayerGamePageState extends State<MultiplayerGamePage> {
  @override
  void initState() {
    super.initState();
    print("방장 토큰: ${widget.hostToken}");

    // 5초 후 실제 게임 페이지로 이동
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) {
            switch (widget.gameId) {
              case "game1":
                return Game1Page(
                  // ← 자기 자신이 아니라 실제 게임 페이지 호출
                  userIds: widget.userIds,
                  hostToken: widget.hostToken,
                );
              case "game2":
                return Game2MultiPage(
                  userIds: widget.userIds,
                  hostToken: widget.hostToken,
                );
              case "game4":
                return Game4MultiPage(
                  userIds: widget.userIds,
                  hostToken: widget.hostToken,
                );
              case "game5":
                return Game5MultiPage(
                  userIds: widget.userIds,
                  hostToken: widget.hostToken,
                );
              case "game6":
                return Game6MultiPage(
                  userIds: widget.userIds,
                  hostToken: widget.hostToken,
                );
              default:
                return Scaffold(
                  body: Center(child: Text("게임을 찾을 수 없습니다.")),
                );
            }
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("멀티플레이 게임")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("게임이 곧 시작됩니다!"),
            const SizedBox(height: 20),
            Text(
              "참가 플레이어: ${widget.userIds.join(", ")}",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
