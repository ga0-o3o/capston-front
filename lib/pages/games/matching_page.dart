import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // 수정: JSON 파싱을 위해 추가
import 'dart:async'; // 수정: 주기적인 호출(Timer)을 위해 추가

/// 매칭 페이지: 매칭 참가 → 준비 완료 → 게임 시작 → 게임 화면 이동
class MatchingPage extends StatefulWidget {
  final Widget Function(String roomId) gameWidgetBuilder;

  const MatchingPage({
    Key? key,
    required this.gameWidgetBuilder,
  }) : super(key: key);

  @override
  State<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends State<MatchingPage> {
  String statusMessage = "매칭 요청 중...";
  bool isLoading = true;
  String? roomId;
  bool isReadyLoading = false;
  bool isStartingGame = false;

  int roomCounter = 0;

  List<String> playerNicknames = [];

  int playerCount = 1;

  // 수정: 주기적인 API 호출을 위한 타이머 객체 추가
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _joinMatch();
  }

  // 수정: 위젯이 사라질 때 타이머를 취소하는 dispose 메서드 추가
  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _waitMode() {
    print("플레이어가 대기 모드를 선택했습니다.");
    setState(() {
      statusMessage = "대기 모드 선택됨. 다른 플레이어를 기다리는 중...";
    });
  }

  Future<void> _joinMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final playerId = prefs.getString("user_id");
    final nickname = prefs.getString("user_nickname");
    final rank = prefs.getString("user_rank");
    final token = prefs.getString("jwt_token");

    if (playerId == null || nickname == null || rank == null || token == null) {
      setState(() {
        statusMessage = "필수 사용자 정보가 없습니다.";
        isLoading = false;
      });
      print("매칭 실패: 필수 사용자 정보 없음");
      return;
    }

    try {
      final url = Uri.parse("http://localhost:8080/join-match");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "playerId": playerId,
          "nickname": nickname,
          "rank": rank,
          "token": token,
        }),
      );

      if (response.statusCode == 200) {
        final body = response.body;

        if (body.startsWith("매칭 성공! 방 ID:")) {
          roomCounter++;
          final id = body.replaceFirst("매칭 성공! 방 ID:", "").trim();

          // 수정: 매칭 성공 시, playerNicknames를 초기화하는 로직 제거. 폴링으로 갱신될 것임.
          setState(() {
            roomId = id;
            isLoading = false;
          });

          print("매칭 성공: 서버ID=$id, 화면표시=방$roomCounter");

          // 수정: 매칭 성공 후, 주기적으로 플레이어 목록을 업데이트하는 로직 시작
          _startPollingRoomInfo();
          return;
        } else {
          setState(() {
            statusMessage = body;
            isLoading = false;
          });
          print("매칭 대기: $body");
          Future.delayed(const Duration(seconds: 3), () {
            if (roomId == null) _joinMatch();
          });
        }
      } else {
        setState(() {
          statusMessage = "매칭 요청 실패: ${response.statusCode}";
          isLoading = false;
        });
        print("매칭 요청 실패: HTTP ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        statusMessage = "에러 발생: $e";
        isLoading = false;
      });
      print("매칭 에러 발생: $e");
    }
  }

  // 수정: 주기적으로 방 정보를 폴링하는 메서드 추가
  void _startPollingRoomInfo() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updatePlayerList();
    });
  }

  // 수정: 플레이어 목록을 가져오는 새로운 메서드 추가
  Future<void> _updatePlayerList() async {
    if (roomId == null) return;
    try {
      final url = Uri.parse("http://localhost:8080/room/$roomId/players");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<String> fetchedNicknames =
            List<String>.from(json.decode(response.body));

        if (!mounted) return; // 위젯이 삭제되었는지 확인

        setState(() {
          playerNicknames = fetchedNicknames;
          // UI의 상태 메시지를 참여자 수에 따라 변경
          if (playerNicknames.length > 1) {
            statusMessage = "매칭 성공! 방 ID: $roomId";
          }
        });
        print("참여자 목록 업데이트: $playerNicknames");
      }
    } catch (e) {
      print("플레이어 목록 업데이트 에러: $e");
    }
  }

  // 기존 _updatePlayerCount() 메서드는 사용되지 않으므로 제거하거나 그대로 둡니다.
  // 이 코드에서는 삭제하여 간결하게 만듭니다.

  Future<void> _setReady() async {
    if (roomId == null) return;
    setState(() {
      isReadyLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final playerId = prefs.getString("user_id");
    if (playerId == null) {
      setState(() {
        statusMessage = "playerId가 없습니다.";
        isReadyLoading = false;
      });
      print("준비 상태 변경 실패: playerId 없음");
      return;
    }

    try {
      final url = Uri.parse("http://localhost:8080/set-ready");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: '''
      {
        "roomId": "$roomId",
        "playerId": "$playerId"
      }
      ''',
      );

      print("준비 상태 응답: ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          statusMessage = response.body;
        });

        if (response.body.startsWith("모든 플레이어 준비 완료!")) {
          print("모든 플레이어 준비 완료, 게임 시작 시도");
          _startGame();
        } else {
          print("준비 완료, 다른 플레이어를 기다리는 중");
        }
      } else {
        setState(() {
          statusMessage = "준비 상태 변경 실패: ${response.statusCode}";
        });
        print("준비 상태 변경 실패: HTTP ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        statusMessage = "에러 발생: $e";
      });
      print("준비 상태 에러 발생: $e");
    } finally {
      setState(() {
        isReadyLoading = false;
      });
    }
  }

  Future<void> _startGame() async {
    if (roomId == null) return;
    setState(() {
      isStartingGame = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final playerId = prefs.getString("user_id");
    if (playerId == null) {
      setState(() {
        statusMessage = "playerId가 없습니다.";
        isStartingGame = false;
      });
      print("게임 시작 실패: playerId 없음");
      return;
    }

    try {
      final url = Uri.parse("http://localhost:8080/start-game");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: '''
      {
        "roomId": "$roomId",
        "playerId": "$playerId"
      }
      ''',
      );

      print("게임 시작 응답: ${response.body}");

      if (response.statusCode == 200 && response.body == "게임이 시작되었습니다!") {
        if (!mounted) return;
        // 수정: 게임 시작 시 타이머 중단
        _pollingTimer?.cancel();
        print("게임 시작 성공, 이동 중...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.gameWidgetBuilder(roomId!)),
        );
      } else {
        setState(() {
          statusMessage = "게임 시작 실패: ${response.body}";
        });
        print("게임 시작 실패: ${response.body}");
      }
    } catch (e) {
      setState(() {
        statusMessage = "에러 발생: $e";
      });
      print("게임 시작 에러 발생: $e");
    } finally {
      setState(() {
        isStartingGame = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("플레이어 매칭"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상태 메시지 표시
            Text(statusMessage, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            // 로딩 표시
            if (isLoading || isReadyLoading || isStartingGame)
              const LinearProgressIndicator(),

            const SizedBox(height: 16),

            // 매칭 성공 시만 방 UI 표시
            if (roomId != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4E6E99), width: 5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("방 ${playerNicknames.length}명", // 수정: 방 번호 대신 참여자 수 표시
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // 수정: 플레이어 닉네임 목록을 동적으로 표시
                    ...playerNicknames.map((n) => Text(n)).toList(),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (roomId != null && !isReadyLoading && !isStartingGame)
              ElevatedButton(
                onPressed: _setReady,
                child: const Text('준비 완료!'),
              ),
            const SizedBox(height: 8),
            if (roomId != null && !isStartingGame)
              ElevatedButton(
                onPressed: _startGame,
                child: const Text('게임 시작!'),
              ),
          ],
        ),
      ),
    );
  }
}
