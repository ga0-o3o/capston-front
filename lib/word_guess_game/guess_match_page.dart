import 'package:flutter/material.dart';
import 'guess_socket_service.dart';
import 'speed_game_play.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gif_view/gif_view.dart';

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
  bool _manualStart = true; // 수동 시작 모드 (3명 모이면 자동 시작)
  bool _inQueue = false;
  int _waitingCount = 0;

  // 매칭 완료 후 대기 변수들
  String? _pendingRoomId;
  String? _pendingUserId;
  bool _navigated = false; // 중복 네비게이션 방지

  int _roomTotal = 3; // Speed Game은 3명

  bool _matchPressed = false;

  bool _matched = false;

  @override
  void initState() {
    super.initState();
    // GuessSocketService가 UrlConfig에서 자동으로 URL을 가져옵니다
    _socket = GuessSocketService();
    _socket.connect();

    _socket.onMessage = (msg) {
      if (!mounted) return;
      final event = msg['event'];

      if (event == 'waiting') {
        if (!mounted) return;

        final cnt = (msg['count'] ?? 0) as int? ?? 0;

        setState(() {
          _waitingCount = cnt;

          // ✅ 이미 매칭 성공했으면 status 건드리지 않기
          if (_matched) return;

          _status = _inQueue ? '매칭 대기 중...' : '대기 중...';
        });
      } else if (event == 'match_success_speed') {
        final roomId = msg['roomId']?.toString() ?? '';
        final myUserId = (msg['myUserId'] ??
                (_loginId.isNotEmpty
                    ? _loginId
                    : 'guest-${DateTime.now().millisecondsSinceEpoch}'))
            .toString();

        if (!mounted) return;
        setState(() {
          _pendingRoomId = roomId;
          _pendingUserId = myUserId;
          _roomTotal = (msg['total'] ?? 3) as int;
          _matched = true; // ✅ 매칭 성공 표시
        });
      } else if (event == 'game_start_speed') {
        // 3명 모임 → 자동 게임 시작
        final roomId = _pendingRoomId ?? msg['roomId']?.toString() ?? '';
        final myUserId = _pendingUserId ??
            (_loginId.isNotEmpty
                ? _loginId
                : 'guest-${DateTime.now().millisecondsSinceEpoch}');

        if (!mounted) return;

        // 🎯 입장 직전에 한 번 더 상태 문구 보여주기
        setState(() {
          _status = '✅ 매칭 완료! 자동으로 게임이 시작됩니다.';
        });

        // ✅ 0.6초 정도 딜레이 후 게임 입장 (문구 눈에 보이게)
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (!mounted) return;
          _goToGameOnce(roomId, myUserId);
        });
      }
    };
  }

  void _goToGameOnce(String roomId, String userId) {
    if (_navigated) return;
    _navigated = true;
    if (mounted) {
      setState(() => _status = '🎯 게임 시작!');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeedGamePlayPage(
          roomId: roomId,
          userId: userId,
          socket: _socket,
        ),
      ),
    ).then((_) {
      // 게임 페이지에서 뒤로 오면 다시 매칭 가능 상태로 초기화
      if (!mounted) return;
      setState(() {
        _navigated = false;
        _pendingRoomId = null;
        _pendingUserId = null;
        _status = '대기 중...';
        _inQueue = false;
      });
    });
  }

  void _startMatch() async {
    if (!mounted) return;

    setState(() {
      _connecting = true;
      _matchPressed = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final loginId = prefs.getString('user_id') ?? '';
    _loginId = loginId;

    if (loginId.isEmpty) {
      print('⚠️ [Speed] 로그인 정보 없음. 로그인 후 이용해주세요.');
      if (!mounted) return;
      setState(() {
        _status = '로그인 정보가 없습니다.';
        _connecting = false;
        _matchPressed = false;
      });
      return;
    }

    await _socket.requestMatch(loginId, manualStart: _manualStart);
    if (!mounted) return;
    setState(() {
      _status = '매칭 대기 중...';
      _inQueue = true;
      _connecting = false;
    });
  }

  Future<void> _sendBackAndExit() async {
    if (_backSent) return;
    _backSent = true;

    final loginId = _loginId;
    final roomId = _pendingRoomId;
    final userId = _pendingUserId;
    final reason = roomId == null ? 'leave_queue' : 'leave_room';

    _socket.sendBack(
      loginId: loginId.isNotEmpty ? loginId : null,
      roomId: roomId,
      userId: userId,
      reason: reason,
    );

    _socket.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

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

                  // ✅ Row overflow 수정: Flexible로 감싸기
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on, size: 32, color: Colors.black),
                      const SizedBox(width: 8),
                      // ✅ FIX: const 제거 (Flexible child는 const 불가)
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
                          fit: BoxFit.contain,
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

                  const SizedBox(height: 10),

                  // 버튼 영역
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
                            elevation: 2,
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

                  const SizedBox(height: 180),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
