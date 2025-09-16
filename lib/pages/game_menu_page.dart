import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'games/game1_page.dart' as game1;
import 'games/game2_page.dart';
import 'games/game2_multi_page.dart';
import 'games/game3_page.dart';
import 'games/game4_page.dart';
import 'games/game4_multi_page.dart';
import 'games/game5_page.dart';
import 'games/game5_multi_page.dart';
import 'games/game6_page.dart';
import 'games/game6_multi_page.dart';
import 'games/dummy_game_page.dart';
import 'games/matching_page.dart';

// -------------------- GameMenuPage --------------------
class GameMenuPage extends StatelessWidget {
  const GameMenuPage({Key? key}) : super(key: key);

  final List<String> gameTitles = const [
    "단어 빨리 맞히기",
    "제시어 영작 게임",
    "미로 탈출",
    "끝말 잇기",
    "빙고 게임",
    "단어 타워 쌓기",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        title: const Text("게임 메뉴"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 20 / 17,
          ),
          itemCount: gameTitles.length,
          itemBuilder: (context, index) {
            String imagePath = "assets/images/game${index + 1}.png";
            return _gameThumbnail(
              imagePath,
              () async {
                if (index == 0) {
                  // 게임 1: 바로 매칭 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchingPage(
                        gameWidgetBuilder: (roomId) =>
                            DummyGamePage(userIds: [], tokens: []),
                      ),
                    ),
                  );
                } else {
                  // 게임 2~6: 모드 선택 페이지
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StartPageWithModes(
                        title: gameTitles[index],
                        soloPage: DummyGamePage(userIds: [], tokens: []),
                        multiPageBuilder: (userIds, tokens) => MatchingPage(
                          gameWidgetBuilder: (roomId) =>
                              DummyGamePage(userIds: userIds, tokens: tokens),
                        ),
                      ),
                    ),
                  );
                }
              },
              gameTitles[index],
            );
          },
        ),
      ),
    );
  }

  Widget _gameThumbnail(String imagePath, VoidCallback onTap, String title) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- StartPageWithModes --------------------
class StartPageWithModes extends StatelessWidget {
  final String title;
  final Widget soloPage;
  final Widget Function(List<String>, List<String>) multiPageBuilder;

  const StartPageWithModes({
    super.key,
    required this.title,
    required this.soloPage,
    required this.multiPageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: Text(title),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeButton(context, "혼자 하기", (_, __) => soloPage),
            const SizedBox(width: 20),
            _modeButton(context, "같이 하기", multiPageBuilder),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(BuildContext context, String label,
      Widget Function(List<String>, List<String>) pageBuilder) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4E6E99),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        final myId = prefs.getString("user_id") ?? "unknown";
        final myToken = prefs.getString("jwt_token") ?? "";

        if (label == "같이 하기") {
          final userIds = [myId];
          final tokens = [myToken];
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => pageBuilder(userIds, tokens)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => pageBuilder([], [])),
          );
        }
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
