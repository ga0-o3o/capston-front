import 'package:flutter/material.dart';

import 'games/game1_page.dart';
import 'games/game2_page.dart';
import 'games/game3_page.dart';
import 'games/game4_page.dart';
import 'games/game5_page.dart';
import 'games/game6_page.dart';

class GameMenuPage extends StatelessWidget {
  const GameMenuPage({Key? key}) : super(key: key);

  final List<String> gameTitles = const [
    "단어 빨리 맞히기",
    "카드 짝 빨리 맞히기",
    "제시어 영작하기",
    "끝말 잇기",
    "빙고 게임",
    "단아 타워 쌓기",
  ];

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
                          return Game2Page();
                        case 2:
                          return Game3Page();
                        case 3:
                          return Game4Page();
                        case 4:
                          return Game5Page();
                        case 5:
                          return Game6Page();
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
