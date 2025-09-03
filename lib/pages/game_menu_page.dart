import 'package:flutter/material.dart';

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
            return _gameThumbnail("assets/images/title.png");
          }),
        ),
      ),
    );
  }

  // 클래스 내부에 정의된 메서드
  Widget _gameThumbnail(String imagePath) {
    return AspectRatio(
      aspectRatio: 3 / 1, //가로 : 세로 = 3 : 1
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
    );
  }
}
