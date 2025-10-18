import 'package:flutter/material.dart';
import '../game/bingo_socket_service.dart';
import 'bingo_game_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BingoMatchPage extends StatefulWidget {
  const BingoMatchPage({super.key});

  @override
  State<BingoMatchPage> createState() => _BingoMatchPageState();
}

class _BingoMatchPageState extends State<BingoMatchPage> {
  late BingoSocketService _socket;
  String _status = '대기 중...';

  @override
  void initState() {
    super.initState();
    _socket = BingoSocketService(
      baseUrl: 'https://semiconical-shela-loftily.ngrok-free.dev',
    );
    _socket.connect();

    _socket.onMessage = (msg) {
      final event = msg['event'];
      if (event == 'waiting') {
        setState(() => _status = '⏳ 대기 인원: ${msg['count']}명');
      } else if (event == 'matched') {
        final roomId = msg['roomId'];
        setState(() => _status = '✅ 매칭 완료! roomId=$roomId');

        // ✅ 매칭 성공 시 게임 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BingoGamePage(
              roomId: roomId,
              userId: '1', // 로그인 유저 ID (임시)
              socket: _socket,
            ),
          ),
        );
      } else if (event == 'game_start') {
        setState(() => _status = '🎯 게임 시작!');
      }
    };
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  void _startMatch() async {
    // ✅ 1. 로그인한 사용자의 loginId 불러오기
    final prefs = await SharedPreferences.getInstance();
    final loginId = prefs.getString('user_id') ?? '';

    if (loginId.isEmpty) {
      print('⚠️ 로그인 정보 없음. 로그인 후 이용해주세요.');
      setState(() => _status = '로그인 정보가 없습니다.');
      return;
    }

    // ✅ 2. 실제 loginId로 매칭 요청
    await _socket.requestMatch(loginId);
    setState(() => _status = '매칭 요청 중...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎮 Bingo Matching')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _startMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6E99),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                '매칭 시작',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
