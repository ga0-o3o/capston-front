import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({Key? key}) : super(key: key);

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  String userId = '';
  String userName = '';
  String nickname = '';
  String userRank = '';
  String selectedCharacter = 'char1';

  // 캐릭터 목록 (이미지 URL 또는 Asset 경로)
  final List<String> characters = [
    'assets/images/char/char0.png',
    'assets/images/char/char1.png',
    'assets/images/char/char2.png',
    'assets/images/char/char3.png',
    'assets/images/char/char4.png',
    'assets/images/char/char5.png',
    'assets/images/char/char6.png',
  ];

  // 해제된 캐릭터 규칙
  final Map<String, List<int>> rankUnlocks = {
    "Beginner": [0],
    "A1": [0, 1],
    "A2": [0, 1, 2],
    "B1": [0, 1, 2, 3],
    "B2": [0, 1, 2, 3, 4],
    "C1": [0, 1, 2, 3, 4, 5],
    "C2": [0, 1, 2, 3, 4, 5, 6],
  };

  // 해제된 캐릭터 (기본으로 char0은 무조건 해제)
  Set<int> unlockedCharacters = {0};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // SharedPreferences에서 사용자 정보 불러오기
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id') ?? '알 수 없음';
      userName = prefs.getString('user_name') ?? '사용자';
      nickname = prefs.getString('user_nickname') ?? '닉네임 없음';
      userRank = prefs.getString('user_rank') ?? 'Beginner';
      selectedCharacter =
          prefs.getString('user_character') ?? 'assets/images/char/char0.png';

      // 랭크 기반으로 캐릭터 잠금 해제
      unlockedCharacters = rankUnlocks[userRank]?.toSet() ?? {0};

      // SharedPreferences에도 저장 (다음 실행 시 유지되도록)
      prefs.setStringList(
        'unlocked_characters',
        unlockedCharacters.map((e) => e.toString()).toList(),
      );
    });
  }

  // 닉네임 변경
  Future<void> _changeNickname() async {
    final TextEditingController _controller = TextEditingController(
      text: nickname,
    );

    final newNickname = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('닉네임 변경'),
            content: TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: '새 닉네임'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(context, _controller.text.trim()),
                child: const Text('변경'),
              ),
            ],
          ),
    );

    if (newNickname == null || newNickname.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getString('user_id') ?? "";

    if (token == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    final uri = Uri.parse("http://localhost:8080/api/user/nickname");

    try {
      final response = await http.put(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // 로그인 시 받은 토큰 사용
        },
        body: jsonEncode({"id": userId, "nickname": newNickname}),
      );

      print('PUT 요청 상태 코드: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          nickname = data['nickname']; // 서버에서 내려온 닉네임 갱신
        });
        await prefs.setString('user_nickname', nickname);

        print("✅ 닉네임 업데이트 성공: $nickname");
      } else if (response.statusCode == 403) {
        print("❌ 권한 거부 403 - 서버에서 JWT 검증 실패 가능");
      } else {
        print("❌ PUT 요청 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ 닉네임 업데이트 중 오류: $e");
    }
  }

  // 로그아웃
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _selectCharacter() async {
    String tempSelected = selectedCharacter; // 임시 선택 변수

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: characters.length,
                itemBuilder: (context, index) {
                  final charPath = characters[index];
                  final isUnlocked = unlockedCharacters.contains(index);

                  return InkWell(
                    borderRadius: BorderRadius.circular(60),
                    onTap:
                        isUnlocked
                            ? () {
                              setState(() {
                                tempSelected = charPath;
                              });
                            }
                            : null,
                    splashColor: Colors.blue.withOpacity(0.3),
                    highlightColor: Colors.transparent,
                    child: AnimatedScale(
                      scale:
                          tempSelected == charPath
                              ? 1.1
                              : 1.0, // 선택된 캐릭터만 살짝 커짐
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 캐릭터 이미지
                          Opacity(
                            opacity: isUnlocked ? 1.0 : 0.4,
                            child: CircleAvatar(
                              backgroundImage: AssetImage(charPath),
                              radius: 60,
                            ),
                          ),

                          // 잠긴 캐릭터 문구
                          if (!isUnlocked)
                            Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: Text(
                                // index로 필요한 랭크 조회
                                '레벨 테스트\n${rankUnlocks.entries.firstWhere((entry) => entry.value.contains(index), orElse: () => MapEntry('Unknown', [index])).key}\n통과 필요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // 선택 표시
                          if (tempSelected == charPath && isUnlocked)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 30,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () async {
                  // 최종 선택 저장
                  setState(() {
                    selectedCharacter = tempSelected;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_character', selectedCharacter);
                  Navigator.pop(context);
                },
                child: const Text('변경'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 정보'),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // CircleAvatar 부분
            GestureDetector(
              onTap: _selectCharacter, // 클릭 시 함수 실행
              child: Container(
                padding: const EdgeInsets.all(5), // 테두리 두께
                decoration: BoxDecoration(
                  color: Colors.white, // 테두리 색상
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 80, // 캐릭터 크기
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: AssetImage(selectedCharacter), // 선택된 캐릭터
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              userName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('닉네임: $nickname', style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _changeNickname,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '랭크: $userRank',
              style: const TextStyle(fontSize: 18, color: Colors.deepPurple),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '로그아웃',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
