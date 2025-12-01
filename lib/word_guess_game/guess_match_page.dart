import 'package:flutter/material.dart';
import 'guess_socket_service.dart';
import 'speed_game_play.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gif_view/gif_view.dart';

/// Speed Game 매칭 페이지
/// 서버(Spring Boot) 이벤트 규칙에 100% 맞춤
class GuessMatchPage extends StatefulWidget {
  const GuessMatchPage({super.key});

  @override
  State<GuessMatchPage> createState() => _GuessMatchPageState();
}

class _GuessMatchPageState extends State<GuessMatchPage> {
  late GuessSocketService _socket;
  String _status = '대기 중...';
  bool _connecting = false;
  bool _backSent = false;

  String _loginId = '';
  bool _manualStart = true;
  bool _inQueue = false;
  int _waitingCount = 0;

  String? _pendingRoomId;
  String? _pendingUserId;
  bool _navigated = false;

  int _roomTotal = 3;
  bool _matchPressed = false;
  bool _matched = false;

  @override
  void initState() {
    super.initState();

    _socket = GuessSocketService();
    _socket.connect();

    _socket.onMessage = (msg) {
      if (!mounted) return;

      final event = msg['event'];
      print('📩 [MatchPage] 이벤트: $event');

      // ========================================
      // 서버 → 클라이언트 이벤트 처리
      // ========================================

      // 대기 인원 수 (커스텀 이벤트)
      if (event == 'waiting') {
        final cnt = (msg['count'] ?? 0);
        setState(() {
          _waitingCount = cnt;
          if (_matched) return;
          _status = _inQueue ? '매칭 대기 중...' : '대기 중...';
        });
      }

      // 1) match_success_speed - 매칭 성공
      else if (event == 'match_success_speed') {
        final roomId = msg['roomId']?.toString() ?? '';
        final myUserId = msg['myUserId']?.toString() ??
            (_loginId.isNotEmpty
                ? _loginId
                : 'guest-${DateTime.now().millisecondsSinceEpoch}');

        setState(() {
          _pendingRoomId = roomId;
          _pendingUserId = myUserId;
          _roomTotal = (msg['total'] ?? 3);
          _matched = true;
          _status = '매칭 성공! 게임이 곧 시작됩니다.';
        });
      }

      // 2) game_start_speed - 게임 시작
      else if (event == 'game_start_speed') {
        final roomId = _pendingRoomId ?? msg['roomId']?.toString() ?? '';
        final myUserId = _pendingUserId ?? _loginId;

        setState(() {
          _status = '✔ 매칭 완료! 게임이 시작됩니다...';
        });

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          _goToGameOnce(roomId, myUserId);
        });
      }

      // 3) match_cancelled - 매칭 취소됨
      else if (event == 'match_cancelled') {
        if (mounted) {
          setState(() {
            _status = '매칭이 취소되었습니다.';
            _inQueue = false;
            _matched = false;
            _matchPressed = false;
            _connecting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('매칭이 취소되었습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // 4) already_in_game - 중복 로그인 감지
      else if (event == 'already_in_game') {
        final message = msg['data']?['message'] ??
            '다른 곳에서 이미 매칭/게임 진행중입니다. 매칭을 시도할 수 없습니다.';

        if (!mounted) return;
        setState(() {
          _connecting = false;
          _inQueue = false;
          _matchPressed = false;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ 중복 로그인'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    };
  }

  /// 게임 페이지로 이동 (중복 방지)
  void _goToGameOnce(String roomId, String userId) {
    if (_navigated) return;
    _navigated = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeedGamePlayPage(
          roomId: roomId,
          userId: userId,
          loginId: _loginId,
          socket: _socket,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        _navigated = false;
        _pendingRoomId = null;
        _pendingUserId = null;
        _inQueue = false;
        _matched = false;
        _matchPressed = false;
        _status = '대기 중...';
      });
    });
  }

  /// 매칭 시작 버튼
  void _startMatch() async {
    setState(() {
      _connecting = true;
      _matchPressed = true;
    });

    final prefs = await SharedPreferences.getInstance();
    _loginId = prefs.getString('user_id') ?? '';

    if (_loginId.isEmpty) {
      setState(() {
        _connecting = false;
        _matchPressed = false;
        _status = '로그인 정보가 필요합니다.';
      });
      return;
    }

    await _socket.requestMatch(_loginId);
    setState(() {
      _status = '매칭 대기 중...';
      _inQueue = true;
      _connecting = false;
    });
  }

  /// 뒤로가기 버튼 (matching_exit 전송)
  Future<void> _sendBackAndExit() async {
    if (_backSent) return;
    _backSent = true;

    _socket.sendMatchingExit(
      loginId: _loginId,
      roomId: _pendingRoomId,
      userId: _pendingUserId,
      reason: 'leave',
    );

    _socket.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  // ========================================
  // UI (디자인 절대 변경 금지)
  // ========================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _sendBackAndExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on, size: 32, color: Colors.black),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Speed Game Matching!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    flex: 4,
                    child: Column(
                      children: [
                        GifView.asset(
                          'assets/images/socketCat1.gif',
                          height: 280,
                          frameRate: 10,
                          autoPlay: true,
                          loop: true,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _status,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Column(
                    children: [
                      SizedBox(
                        width: 250,
                        child: ElevatedButton(
                          onPressed: (_connecting || _matchPressed)
                              ? null
                              : _startMatch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _connecting ? '연결 중...' : '매칭 시작',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 250,
                        child: OutlinedButton(
                          onPressed: _sendBackAndExit,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: Color(0xFF4E6E99),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '뒤로 가기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4E6E99),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
