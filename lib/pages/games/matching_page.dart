import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    _joinMatch();
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
          "Authorization": "Bearer $token", // JWT 토큰 헤더로 전달
        },
        body: '''
    {
      "playerId": "$playerId",
      "playerNickname": "$nickname",
      "rank": "$rank",
      "token": "$token"
    }
    ''',
      );

      if (response.statusCode == 200) {
        final body = response.body;
        print("매칭 응답: $body");

        if (body.startsWith("매칭 성공! 방 ID:")) {
          roomCounter++;
          final id = body.replaceFirst("매칭 성공! 방 ID:", "").trim();

          final prefs = await SharedPreferences.getInstance();
          final nickname = prefs.getString("user_nickname") ?? "알 수 없음";

          setState(() {
            roomId = id;
            playerNicknames = [nickname]; // 본인 닉네임 추가
            playerCount = 1; // 현재는 자기 자신만
            isLoading = false;
          });

          print("매칭 성공: 서버ID=$id, 화면표시=방$roomCounter, 닉네임=$nickname");
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

  Future<void> _updatePlayerCount() async {
    if (roomId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final myNickname = prefs.getString("user_nickname") ?? "알 수 없음";

    // playerCount만큼 본인 닉네임으로 리스트 생성
    setState(() {
      playerCount = playerCount; // 서버에서 받아온 참여자 수로 유지 가능
      playerNicknames = List.generate(playerCount, (_) => myNickname);
    });

    try {
      final url = Uri.parse("http://localhost:8080/room/$roomId/player-count");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final count = int.tryParse(response.body);
        if (count != null) {
          setState(() {
            playerCount = count;
          });
          print("참여자 수 업데이트: $playerCount 명");
        }
      }
    } catch (e) {
      print("참여자 수 업데이트 에러: $e");
    }
  }

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // 좌우 꽉 채우기
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(), // 혹은 CircularProgressIndicator
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4E6E99), width: 5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(statusMessage, style: TextStyle(fontSize: 16)),
                  ),
                  if (isLoading) const LinearProgressIndicator(),
                  if (roomId != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF4E6E99), width: 5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("방 $roomCounter",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...playerNicknames.map((n) => Text(n)).toList(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
