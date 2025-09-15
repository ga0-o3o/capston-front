import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'games/game1_page.dart';
import 'games/game2_page.dart';
import 'games/game2_multi_page.dart';
import 'games/game3_page.dart';
import 'games/game4_page.dart';
import 'games/game4_multi_page.dart';
import 'games/game5_page.dart';
import 'games/game6_page.dart';
import 'games/game6_multi_page.dart';

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

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("userId");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9), // 배경 색상
      appBar: AppBar(
        title: const Text("게임 메뉴"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 한 줄에 2개
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 20 / 17, // 이미지 + 제목 비율 고려
          ),
          itemCount: gameTitles.length,
          itemBuilder: (context, index) {
            String imagePath = "assets/images/game${index + 1}.png";
            return _gameThumbnail(
              imagePath,
              () {
                // 클릭 시 페이지 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      switch (index) {
                        case 0:
                          return Game1Page();
                        case 1:
                          return StartPageWithModes(
                            title: "제시어 영작 게임",
                            soloPage: const Game2Page(),
                            multiPage: const Game2MultiPage(),
                          );
                        case 2:
                          return Game3Page();
                        case 3:
                          return StartPageWithModes(
                            title: "끝말잇기",
                            soloPage: const Game4Page(),
                            multiPage: const Game4MultiPage(),
                          );
                        case 4:
                          return Game5Page();
                        case 5:
                          return StartPageWithModes(
                            title: "단어 타워 쌓기",
                            soloPage: const Game6Page(),
                            multiPage: const Game6MultiPage(),
                          );
                        default:
                          return Game1Page();
                      }
                    },
                  ),
                );
              },
              gameTitles[index], // 제목 전달
            );
          },
        ),
      ),
    );
  }

  // 클릭 가능한 게임 썸네일 (이미지 + 제목)
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

class StartPageWithModes extends StatelessWidget {
  final String title;
  final Widget soloPage;
  final Widget multiPage;

  const StartPageWithModes({
    super.key,
    required this.title,
    required this.soloPage,
    required this.multiPage,
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
            _modeButton(context, "혼자 하기", soloPage),
            const SizedBox(width: 20),
            _modeButton(context, "같이 하기", multiPage),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(BuildContext context, String label, Widget page) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4E6E99),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
