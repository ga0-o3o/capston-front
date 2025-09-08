import 'package:flutter/material.dart';
import 'game_menu_page.dart';
import 'levelTest_page.dart';

class MainMenuPage extends StatelessWidget {
  final String userName;

  MainMenuPage({Key? key, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 로고 + 사용자 프로필 + 햄버거 메뉴
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/title.png',
                    height: 60,
                    fit: BoxFit.contain,
                  ),

                  Row(
                    children: [
                      // 사용자 프로필 (이모티콘 동그라미)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserInfoPage(userName: userName),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.blue[200],
                          radius: 20,
                          child: const Text(
                            "👤", // 이모티콘 (원하는 거 넣어도 됨)
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 햄버거 메뉴 버튼
                      IconButton(
                        icon: const Icon(
                          Icons.menu,
                          size: 28,
                          color: Colors.black87,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('메뉴 버튼 클릭됨')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 버튼 목록
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _menuButton(context, '📚 단어장', () {
                      // 단어장 페이지로 이동
                    }),
                    const SizedBox(height: 16),
                    _menuButton(context, '🎮 게임', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GameMenuPage(),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    _menuButton(context, '📈 레벨 테스트', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const LevelTestPage(), // 레벨 테스트 페이지
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    _menuButton(context, '📊 스테이터스', () {
                      // 통계 페이지로 이동
                    }),
                    const SizedBox(height: 16),
                    _menuButton(context, '⚙️ 설정', () {
                      // 설정 페이지 이동
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 버튼 스타일
  Widget _menuButton(
    BuildContext context,
    String title,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E6E99),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// 👉 사용자 정보 페이지
class UserInfoPage extends StatelessWidget {
  final String userName;

  const UserInfoPage({Key? key, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("사용자 정보")),
      body: Center(
        child: Text(
          "안녕하세요, $userName 님!",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
