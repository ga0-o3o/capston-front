import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatingPage extends StatefulWidget {
  const ChatingPage({Key? key}) : super(key: key);

  @override
  State<ChatingPage> createState() => _ChatingPageState();
}

class _ChatingPageState extends State<ChatingPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(text);
    });
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF3D4C63), // 네이비 배경
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            const DrawerHeader(
              child: Text(
                '채팅 목록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('홍길동'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('김철수'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('이영희'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 왼쪽 다시하기 아이콘
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      // 다시하기 기능 구현하기
                    },
                  ),

                  // 중앙 필기체 글씨
                  Expanded(
                    child: Center(
                      child: Text(
                        'HiLight',
                        style: GoogleFonts.pacifico(
                          fontSize: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // 오른쪽 햄버거 아이콘
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

          // 흰색 볼록 영역
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
                  // 메시지 리스트
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ListView.builder(
                        reverse: true, // 새로운 메시지가 아래가 아닌 위로
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message =
                              _messages[_messages.length - 1 - index];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                message,
                                style: const TextStyle(fontSize: 16),
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
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: '메시지를 입력하세요...',
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
