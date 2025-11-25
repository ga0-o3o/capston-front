import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login/login_page.dart';
import 'loading_page.dart';
import 'login/login_service.dart';

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
    final TextEditingController _controller =
        TextEditingController(text: nickname);

    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController _controller =
            TextEditingController(text: nickname);

        return Dialog(
          backgroundColor: Colors.transparent, // 배경 투명
          child: SizedBox(
            width: 350,
            height: 350,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 배경 이미지
                Image.asset(
                  'assets/images/dialog1.png',
                  width: 350,
                  height: 350,
                  fit: BoxFit.contain,
                ),

                // 중앙 텍스트와 입력, 버튼
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '닉네임 변경',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          labelText: '새 닉네임',
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context), // null 반환 없이 단순 닫기
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFCC8C8),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                  color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, _controller.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                  color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text(
                            '변경',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (newNickname == null) {
      // 취소한 경우는 아무 처리 없이 종료
      return;
    }

    if (newNickname.isEmpty || newNickname.length > 12) {
      showDialog(
        context: context,
        barrierDismissible: false, // 바깥 클릭으로 닫히지 않게
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent, // 배경 투명
            child: SizedBox(
              width: 370,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 배경 이미지
                  Image.asset(
                    'assets/images/dialog2.png',
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),

                  // 중앙에 텍스트와 버튼 배치
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '경고',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '닉네임은 1자 이상 12자 이하로 해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFCC8C8),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(100, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0), // 네모
                            side: const BorderSide(
                              color: Colors.black,
                              width: 2, // 테두리 두께
                            ),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    // 새 닉네임 길이가 정상일 경우 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 370,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 배경 이미지
                Image.asset(
                  'assets/images/dialog2.png',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
                // 중앙 텍스트와 버튼
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '닉네임 변경 확인',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '정말로 닉네임을 변경하시겠습니까?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFCC8C8),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                  color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text('취소',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                  color: Colors.black, width: 2),
                            ),
                          ),
                          child: const Text('변경',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // 취소하면 종료
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getString('user_id') ?? "";

    if (token == null || userId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    final uri = Uri.parse(
        "https://semiconical-shela-loftily.ngrok-free.dev/api/v1/users/$userId/nickname");

    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LoadingPage()));

    try {
      final response = await http.put(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"nickname": newNickname}),
      );

      Navigator.pop(context); // 로딩 닫기

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          nickname = data['nickname'];
        });
        await prefs.setString('user_nickname', nickname);

        showDialog(
          context: context,
          barrierDismissible: false, // 바깥 클릭으로 닫히지 않게
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 300, // 다이얼로그 전체 너비 조정
                height: 250, // 다이얼로그 전체 높이 조정
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 배경 이미지
                    Image.asset(
                      'assets/images/dialog1.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),

                    // 중앙에 텍스트와 버튼 배치
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '알림',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '닉네임이 변경되었습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        print("❌ PUT 요청 실패: ${response.statusCode}");
      }
    } catch (e) {
      Navigator.pop(context);
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
      backgroundColor: const Color.fromARGB(255, 237, 237, 236),
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
                    onTap: isUnlocked
                        ? () {
                            setState(() {
                              tempSelected = charPath;
                            });
                          }
                        : null,
                    splashColor: Colors.blue.withOpacity(0.3),
                    highlightColor: Colors.transparent,
                    child: AnimatedScale(
                      scale: tempSelected == charPath ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 캐릭터 배경 색상 적용
                          Container(
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? const Color(0xFF3D4C63)
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              backgroundImage: AssetImage(charPath),
                              radius: 60,
                              backgroundColor:
                                  Colors.transparent, // 배경색은 위 Container가 담당
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
                                '레벨 테스트\n${rankUnlocks.entries.firstWhere((entry) => entry.value.contains(index), orElse: () => MapEntry('Unknown', [
                                          index
                                        ])).key}\n통과 필요',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D4C63), // 배경 색상
                  foregroundColor: Colors.white, // 글자 색상
                  minimumSize: const Size(200, 50), // 버튼 크기
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10), // 내부 여백
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // 둥근 모서리
                  ),
                ),
                child: const Text(
                  '변경',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
      backgroundColor: const Color(0xFFF6F0E9),
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
