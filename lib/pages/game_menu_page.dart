import 'package:flutter/material.dart';

import 'games/game1_page.dart';
import 'games/game2_page.dart';
import 'games/game3_page.dart';
import 'games/game4_page.dart';
import 'games/game5_page.dart';
import 'games/game6_page.dart';

class GameMenuPage extends StatelessWidget {
  const GameMenuPage({Key? key}) : super(key: key);

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
        child: GridView.count(
          crossAxisCount: 2, // 한 줄에 2개
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: List.generate(6, (index) {
            String imagePath = "assets/images/game${index + 1}.png"; // 이미지 경로
            return _gameThumbnail(imagePath, () {
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
            });
          }),
        ),
      ),
    );
  }

  // 클릭 가능한 게임 썸네일
  Widget _gameThumbnail(String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 3 / 1, // 가로:세로 = 3:1
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(imagePath, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
