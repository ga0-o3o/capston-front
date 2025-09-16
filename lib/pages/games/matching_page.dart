import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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

  List<String> playerNicknames = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _joinMatch();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// 매칭 요청
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
          final id = body.replaceFirst("매칭 성공! 방 ID:", "").trim();

          setState(() {
            roomId = id;
            isLoading = false;
            playerNicknames = [nickname]; // 내 닉네임 먼저 추가
          });

          print("매칭 성공: 서버ID=$id");

          // 첫 갱신을 1초 뒤 호출하고 주기적 갱신 시작
          Future.delayed(const Duration(seconds: 1), () {
            _updatePlayerList();
            _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              _updatePlayerList();
            });
          });
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

  /// 서버에서 플레이어 목록 가져오기
  Future<void> _updatePlayerList() async {
    if (roomId == null) return;
    try {
      final url = Uri.parse("http://localhost:8080/room/$roomId/players");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);

        // 서버가 문자열 배열이면
        final fetchedNicknames = list.map((e) => e.toString()).toList();

        if (!mounted) return;

        setState(() {
          playerNicknames = fetchedNicknames;
          if (playerNicknames.isNotEmpty) {
            statusMessage = "매칭 성공! 방 ID: $roomId";
          }
        });
        print("참여자 목록 업데이트: $playerNicknames");
      }
    } catch (e) {
      print("플레이어 목록 업데이트 에러: $e");
    }
  }

  /// 준비 상태 전송
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
      return;
    }

    try {
      final url = Uri.parse("http://localhost:8080/set-ready");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "playerId": playerId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          statusMessage = response.body;
        });

        if (response.body.startsWith("모든 플레이어 준비 완료!")) {
          _startGame();
        }
      } else {
        setState(() {
          statusMessage = "준비 상태 변경 실패: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "에러 발생: $e";
      });
    } finally {
      setState(() {
        isReadyLoading = false;
      });
    }
  }

  /// 게임 시작 요청
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
      return;
    }

    try {
      final url = Uri.parse("http://localhost:8080/start-game");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "playerId": playerId,
        }),
      );

      if (response.statusCode == 200 && response.body == "게임이 시작되었습니다!") {
        if (!mounted) return;
        _pollingTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.gameWidgetBuilder(roomId!)),
        );
      } else {
        setState(() {
          statusMessage = "게임 시작 실패: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "에러 발생: $e";
      });
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
            Text(statusMessage, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            if (isLoading || isReadyLoading || isStartingGame)
              const LinearProgressIndicator(),
            const SizedBox(height: 16),
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
                    Text("방 ${playerNicknames.length}명",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
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
