import 'package:flutter/material.dart';
import 'bingo_socket_service.dart';
import 'bingo_game_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gif_view/gif_view.dart';

class BingoMatchPage extends StatefulWidget {
  const BingoMatchPage({super.key});

  @override
  State<BingoMatchPage> createState() => _BingoMatchPageState();
}

class _BingoMatchPageState extends State<BingoMatchPage> {
  late BingoSocketService _socket;
  String _status = '대기 중...';
  bool _connecting = false;
  bool _backSent = false;

  String? _loginId;
  bool _manualStart = true; // ✅ 수동 시작 모드
  bool _inQueue = false;
  int _waitingCount = 0;
  bool get _canStartNow => _inQueue && _pendingRoomId != null;

  bool _matchPressed = false;

  // ✅ 수동 시작 모드를 위한 대기 변수들
  String? _pendingRoomId;
  String? _pendingUserId;
  bool _readyToStart = false; // 사용자가 ‘지금 시작’ 눌렀는지
  bool _navigated = false; // 중복 네비게이션 방지

  bool _meReady = false; // 내가 ‘지금 시작(Ready)’ 눌렀는지
  bool _peerReady = false; // 상대가 Ready인지(ready_update로 갱신)
  int _readyCount = 0;
  int _roomTotal = 2;

  @override
  void initState() {
    super.initState();
    // ✅ BingoSocketService가 UrlConfig에서 자동으로 URL을 가져옵니다
    _socket = BingoSocketService();
    _socket.connect();

    _socket.onMessage = (msg) {
      if (!mounted) return; // ✅ mounted 체크 추가
      final event = msg['event'];

      if (event == 'waiting') {
        final cnt = (msg['count'] ?? 0) as int;
        if (!mounted) return; // ✅ setState 전 체크
        setState(() {
          _waitingCount = cnt;
        });
      } else if (event == 'matched') {
        final roomId = msg['roomId']?.toString() ?? '';
        final myUserId = (msg['myUserId'] ??
                _loginId ??
                'guest-${DateTime.now().millisecondsSinceEpoch}')
            .toString();

        if (_manualStart) {
          if (!mounted) return; // ✅ setState 전 체크
          setState(() {
            _pendingRoomId = roomId;
            _pendingUserId = myUserId;
            _status = '✅ 매칭 완료! "지금 시작"을 \n모두 누르면 게임이 시작됩니다.';
            _meReady = false;
            _peerReady = false;
            _readyCount = 0;
            _roomTotal = (msg['total'] ?? 2) as int; // 서버가 보내면 사용, 아니면 2
          });
        } else {
          _goToGameOnce(roomId, myUserId);
        }
      } else if (event == 'ready_update') {
        // 서버가 준비 현황 브로드캐스트
        final roomId = msg['roomId']?.toString() ?? _pendingRoomId ?? '';
        final readyCount = (msg['readyCount'] ?? 0) as int;
        final total = (msg['total'] ?? _roomTotal) as int;
        // 선택: readyUsers에 내 userId 포함 여부로 _meReady 재확인 가능
        final readyUsers =
            (msg['readyUsers'] as List?)?.map((e) => e.toString()).toList() ??
                [];
        final meId = _pendingUserId ?? _loginId ?? '';
        final meReadyNow = readyUsers.contains(meId);

        if (!mounted) return; // ✅ setState 전 체크
        setState(() {
          _pendingRoomId ??= roomId;
          _readyCount = readyCount;
          _roomTotal = total;
          _meReady = meReadyNow || _meReady; // 내가 이미 눌렀다면 true 유지
          _peerReady = (readyCount >= 1 && total >= 2)
              ? (readyCount == total
                  ? true
                  : (_meReady ? (readyCount >= 2) : (readyCount >= 1)))
              : false;
          _status = '🟢 준비 현황: $readyCount / $total';
        });
      } else if (event == 'game_start') {
        // ✅ 모두 준비되었을 때만 이동 (안전가드)
        if (_manualStart && !_meReady) {
          print('ℹ️ 내가 Ready가 아니므로 game_start 무시');
          return;
        }
        final roomId = _pendingRoomId ?? msg['roomId']?.toString() ?? '';
        final myUserId = _pendingUserId ??
            _loginId ??
            'guest-${DateTime.now().millisecondsSinceEpoch}';
        _goToGameOnce(roomId, myUserId);
      } else if (event == 'already_in_game') {
        // 🚨 중복 로그인 감지: 팝업 표시
        final message = msg['data']?['message'] ??
            '다른 곳에서 이미 매칭/게임 진행중입니다. 매칭을 시도할 수 없습니다.';

        if (!mounted) return;
        setState(() {
          _connecting = false;
          _inQueue = false;
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

  void _goToGameOnce(String roomId, String userId) {
    if (_navigated) return;
    _navigated = true;
    if (mounted) {
      setState(() => _status = '🎯 게임 시작!');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BingoGamePage(
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
        _readyToStart = false;
        _status = '대기 중...';
      });
    });
  }

  void _startMatch() async {
    if (!mounted) return;

    if (!mounted) return;
    setState(() {
      _connecting = true;
      _matchPressed = true; // ✅ 여기서 잠금
    });

    final prefs = await SharedPreferences.getInstance();
    final loginId = prefs.getString('user_id') ?? '';
    _loginId = loginId;

    if (loginId.isEmpty) {
      print('⚠️ 로그인 정보 없음. 로그인 후 이용해주세요.');
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
      _status = _manualStart ? '매칭 대기 중...' : '매칭 요청 중...';
      _inQueue = true;
      _connecting = false;
    });
  }

  void _startNow() {
    // ✅ 사용자가 "지금 시작" 누름
    _readyToStart = true;

    if (_pendingRoomId != null && _pendingUserId != null) {
      // 이미 매칭됨: 바로 진입
      _goToGameOnce(_pendingRoomId!, _pendingUserId!);
    } else {
      // 아직 roomId를 못 받은 케이스: 서버에 강제 시작 요청
      _socket.forceStartMatch();
      if (!mounted) return;
      setState(() {
        _status = '🎬 지금 시작 요청!';
      });
    }
  }

  Future<void> _sendBackAndExit() async {
    if (_backSent) return;
    _backSent = true;

    // 매칭 여부에 따라 보낼 JSON 구성 (서비스가 JSON으로 직렬화해서 전송함)
    final loginId = _loginId ?? '';
    final roomId = _pendingRoomId; // 매칭 전이면 null
    final userId = _pendingUserId; // 매칭 전이면 null
    final reason = roomId == null ? 'leave_queue' : 'leave_room';

    // ✅ JSON 페이로드 전송: {event:"send_back", loginId, roomId?, userId?, reason}
    _socket.sendBack(
      loginId: loginId.isNotEmpty ? loginId : null,
      roomId: roomId,
      userId: userId,
      reason: reason,
    );

    // 연결 종료 및 화면 닫기
    _socket.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // WebSocket 정리
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ '지금 시작' 버튼 노출 조건: 매칭이 완료되어 roomId를 받은 경우
    final canShowStartNow = _inQueue && _pendingRoomId != null;

    return WillPopScope(
      onWillPop: () async {
        await _sendBackAndExit(); // ← JSON 전송
        return false; // 우리가 직접 pop 처리
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true, // 키보드가 나타날 때 화면 자동 조정
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
                    children: const [
                      Icon(Icons.videogame_asset,
                          size: 36, color: Colors.black),
                      SizedBox(width: 10),
                      Text(
                        'Bingo Matching!',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
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
                          height: 300,
                          frameRate: 10,
                          autoPlay: true,
                          loop: true,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _status,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 버튼 영역
                  Column(
                    children: [
                      SizedBox(
                        width: 250,
                        child: ElevatedButton(
                          onPressed: _connecting
                              ? null
                              : (_canStartNow
                                  ? _startNow
                                  : (_matchPressed ? null : _startMatch)),
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
                            _connecting
                                ? '연결 중...'
                                : (_canStartNow ? '지금 시작' : '매칭 시작'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 필요 시 '뒤로 가기'는 그대로 유지
                      SizedBox(
                        width: 250,
                        child: OutlinedButton(
                          onPressed: _sendBackAndExit, // ← JSON 전송 + 종료
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: Color(0xFF4E6E99), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
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
