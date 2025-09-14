// lib/pages/main_menu_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_menu_page.dart';
import 'levelTest_page.dart';
import 'userInfo_page.dart';
import 'word_menu_page.dart';

class MainMenuPage extends StatefulWidget {
  final String userName;
  const MainMenuPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  String selectedCharacter = 'assets/images/char/char0.png';

  @override
  void initState() {
    super.initState();
    _loadSelectedCharacter();
  }

  Future<void> _loadSelectedCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCharacter =
          prefs.getString('user_character') ?? 'assets/images/char/char0.png';
    });
  }

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
                  Image.asset('assets/images/title.png',
                      height: 60, fit: BoxFit.contain),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UserInfoPage()),
                          );
                          _loadSelectedCharacter();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: CircleAvatar(
                              radius: 30,
                              backgroundImage: AssetImage(selectedCharacter)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.menu,
                            size: 28, color: Colors.black87),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WordMenuPage()),
                      );
                    }),
                    const SizedBox(height: 16),
                    _menuButton(context, '🎮 게임', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GameMenuPage()),
                      );
                    }),
                    const SizedBox(height: 16),
                    _menuButton(context, '📈 레벨 테스트', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LevelTestPage()),
                      );
                    }),
                    const SizedBox(height: 16),
                    _menuButton(context, '📊 스테이터스', () {}),
                    const SizedBox(height: 16),
                    _menuButton(context, '⚙️ 설정', () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공통 버튼
  Widget _menuButton(
      BuildContext context, String title, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E6E99),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
