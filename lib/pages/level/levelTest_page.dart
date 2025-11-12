import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelTestPage extends StatefulWidget {
  const LevelTestPage({Key? key}) : super(key: key);

  @override
  State<LevelTestPage> createState() => _LevelTestChatPageState();
}

class _LevelTestChatPageState extends State<LevelTestPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 간단한 질문 시나리오
  final List<String> _questions = [
    "안녕하세요! 😊 영어 실력 테스트를 시작할게요.",
    "영어로 자기소개를 한 문장으로 해볼까요?",
    "모든 질문이 끝났어요! 당신의 레벨을 분석 중입니다... ⏳"
  ];

  List<_ChatMessage> _messages = [];
  int _currentQuestionIndex = 0;
  bool _testFinished = false;

  @override
  void initState() {
    super.initState();
    // 첫 질문 출력
    Future.delayed(const Duration(milliseconds: 600), () {
      _addBotMessage(_questions[_currentQuestionIndex]);
    });
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _testFinished) return;

    _addUserMessage(text);
    _controller.clear();

    // 다음 질문 or 결과로 진행
    if (_currentQuestionIndex < _questions.length - 1) {
      _currentQuestionIndex++;
      Future.delayed(const Duration(milliseconds: 800), () {
        _addBotMessage(_questions[_currentQuestionIndex]);
      });
    } else {
      _finishTest();
    }
  }

  void _finishTest() async {
    setState(() => _testFinished = true);

    await Future.delayed(const Duration(seconds: 2));
    _addBotMessage("테스트가 완료되었습니다 🎉");

    await Future.delayed(const Duration(seconds: 1));

    // 🔹 간단한 평가 로직 예시
    // 실제로는 답변의 길이나 키워드, 점수 등을 기반으로 바꿀 수 있음
    final int lengthScore = _messages
        .where((m) => m.isUser)
        .map((m) => m.text.split(' ').length)
        .fold(0, (a, b) => a + b);

    String level;
    if (lengthScore < 5) {
      level = "A1 (Beginner)";
    } else if (lengthScore < 10) {
      level = "A2 (Elementary)";
    } else if (lengthScore < 20) {
      level = "B1 (Intermediate)";
    } else if (lengthScore < 30) {
      level = "B2 (Upper-Intermediate)";
    } else if (lengthScore < 40) {
      level = "C1 (Advanced)";
    } else {
      level = "C2 (Proficient)";
    }

    _addBotMessage("당신의 예상 영어 레벨은 ✨ **$level** ✨ 입니다!");
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF3D4C63),
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: const [
            DrawerHeader(
              child: Text(
                '레벨 테스트 채팅',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(title: Text('테스트 기록 보기')),
            ListTile(title: Text('레벨 설명')),
            ListTile(title: Text('설정')),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 상단 바
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _messages.clear();
                        _currentQuestionIndex = 0;
                        _testFinished = false;
                      });
                      _addBotMessage(_questions[0]);
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Level Test',
                        style: GoogleFonts.pacifico(
                          fontSize: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) => IconButton(
                      icon:
                          const Icon(Icons.menu, color: Colors.white, size: 30),
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 채팅 영역
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: screenHeight * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEDEC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  // 채팅 리스트
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return Align(
                            alignment: msg.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? const Color(0xFF4E6E99)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      msg.isUser ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 입력창
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_testFinished,
                            decoration: InputDecoration(
                              hintText: _testFinished
                                  ? '테스트가 완료되었습니다.'
                                  : '답변을 입력하세요...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _sendMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----- 메시지 모델 -----
class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}
