import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'word_front_page.dart';
import 'game_menu_page.dart';
import 'levelTest_page.dart';
import 'userInfo_page.dart';
import 'word_menu_page.dart';
import 'chating_page.dart';

class MainMenuPage extends StatefulWidget {
  final String userName;
  const MainMenuPage({Key? key, required this.userName}) : super(key: key);

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  int _selectedCharacterIndex = 0; // 추가: 캐릭터 번호
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  final List<Widget> _pages = [
    SizedBox(), // 홈
    const WordFrontPage(),
    const GameMenuPage(),
    const LevelTestPage(),
    const ChatingPage(), // 채팅
    const SizedBox(), // 토론
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedCharacter();
  }

  Future<void> _loadSelectedCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedPath =
        prefs.getString('user_character') ?? 'assets/images/char/char0.png';

    // char{숫자} 부분만 추출
    final regex = RegExp(r'char(\d+)');
    final match = regex.firstMatch(selectedPath);
    final index = match != null ? int.parse(match.group(1)!) : 0;

    setState(() {
      _selectedCharacterIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: _currentIndex == 0
          ? SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 타이틀과 프로필
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Row(
                      children: [
                        Text(
                          'HiLight',
                          style: GoogleFonts.pacifico(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4E6E99), // 글씨 색상 변경
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const UserInfoPage()),
                        );
                        _loadSelectedCharacter(); // 돌아온 뒤 GIF 업데이트
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4), // 테두리 두께
                        decoration: BoxDecoration(
                          color: Colors.white, // 테두리 색상
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: SizedBox(
                            width: 180,
                            height: 180,
                            child: Image.asset(
                              'assets/videos/char${_selectedCharacterIndex}_run.gif',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFFEBE3D5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(6, (index) {
            final isSelected = _currentIndex == index;
            final icons = [
              Icons.home,
              Icons.book,
              Icons.videogame_asset,
              Icons.assessment,
              Icons.chat,
              Icons.forum,
            ];
            final labels = ['홈', '단어장', '게임', '레벨 테스트', '채팅', '토론'];

            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.all(isSelected ? 8 : 0),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? Color(0xFF3D4C63) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedScale(
                      scale: isSelected ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        icons[index],
                        color: isSelected ? Colors.white : Color(0xFF3D4C63),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _menuButton(BuildContext context, String title, VoidCallback onPressed,
      {IconData? icon}) {
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
