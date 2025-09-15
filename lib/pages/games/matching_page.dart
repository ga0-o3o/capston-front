import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'multiplayer_game_page.dart';

class MatchingPage extends StatefulWidget {
  final Widget Function(List<String> userIds, String hostToken)
      gameWidgetBuilder;
  final String gameId; // 게임 종류

  const MatchingPage({
    Key? key,
    required this.gameWidgetBuilder,
    required this.gameId,
  }) : super(key: key);

  @override
  State<MatchingPage> createState() => _MatchingPageState();
}

class Room {
  final int maxPlayers;
  final String gameId;
  final String rank;
  final String roomName;
  List<String> playerIds = [];
  Map<String, String> nicknames = {};
  Map<String, bool> readyStatus = {}; // userId -> 준비 여부
  String? hostId;
  String? hostToken;

  Room(
      {required this.gameId,
      required this.rank,
      required this.roomName,
      this.maxPlayers = 5});

  bool get isFull => playerIds.length >= maxPlayers;

  void addPlayer(String userId, String nickname, String? token) {
    if (isFull) return;
    playerIds.add(userId);
    nicknames[userId] = nickname;
    readyStatus[userId] = false; // 처음엔 준비 상태 false
    if (hostId == null) {
      hostId = userId;
      hostToken = token;
    }
  }

  void removePlayer(String userId) {
    playerIds.remove(userId);
    nicknames.remove(userId);
    readyStatus.remove(userId);
    if (hostId == userId && playerIds.isNotEmpty) {
      hostId = playerIds.first;
    }
    if (playerIds.isEmpty) {
      hostId = null;
      hostToken = null;
    }
  }

  void setReady(String userId) {
    if (playerIds.contains(userId)) {
      readyStatus[userId] = true;
    }
  }

  bool get allReady =>
      readyStatus.isNotEmpty &&
      readyStatus.values.length == playerIds.length &&
      readyStatus.values.every((v) => v);
}

class _MatchingPageState extends State<MatchingPage> {
  final List<Room> rooms = [];
  String? currentUserId;
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    _addCurrentUser().then((_) {
      joinMatchmaking();
    });
  }

  Future<void> _addCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userIdFromPrefs = prefs.getString("user_id");
    final userNickNameFromPrefs = prefs.getString("user_nickname");
    final tokenFromPrefs = prefs.getString("jwt_token");
    final rankFromPrefs = prefs.getString("user_rank");

    if (userIdFromPrefs != null &&
        userNickNameFromPrefs != null &&
        rankFromPrefs != null) {
      currentUserId = userIdFromPrefs;

      Room? targetRoom;

      // 같은 게임, 같은 랭크 방 찾기
      for (var room in rooms) {
        if (!room.isFull &&
            room.gameId == widget.gameId &&
            room.rank == rankFromPrefs) {
          targetRoom = room;
          break;
        }
      }

      // 없으면 새 방 생성
      if (targetRoom == null) {
        int count = rooms
            .where((r) => r.gameId == widget.gameId && r.rank == rankFromPrefs)
            .length;

        String newRoomName = "${widget.gameId}_${count + 1}";
        targetRoom = Room(
          gameId: widget.gameId,
          rank: rankFromPrefs,
          roomName: newRoomName,
        );

        rooms.add(targetRoom);
      }

      setState(() {
        targetRoom!
            .addPlayer(userIdFromPrefs, userNickNameFromPrefs, tokenFromPrefs);
      });
    }
  }

  // -------------------- 매칭 API 호출 --------------------
  Future<void> joinMatchmaking() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    if (token == null) return;

    final url = Uri.parse("http://localhost:8080/api/game/lobby/join");
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: '{}',
    );

    if (response.statusCode == 200) {
      print("매칭 요청 완료");
      _connectWebSocket(token);
    } else {
      print("매칭 요청 실패: ${response.statusCode}");
    }
  }

  // -------------------- WebSocket 연결 --------------------
  void _connectWebSocket(String token) {
    channel = WebSocketChannel.connect(
      Uri.parse("ws://localhost:8080/ws/matchmaking?token=$token"),
    );

    channel.stream.listen((message) {
      print("WebSocket 메시지: $message");
      if (message.toString().startsWith("Match found!")) {
        final sessionId = message.toString().split("Session ID: ").last;
        print("매칭 완료! 세션 ID: $sessionId");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => widget.gameWidgetBuilder([currentUserId!], token),
          ),
        );
      }
    });
  }

  void _startGame(Room room) {
    if (room.playerIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("최소 2명 이상이어야 게임을 시작할 수 있습니다.")),
      );
      return;
    }

    if (room.hostToken == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            widget.gameWidgetBuilder(room.playerIds, room.hostToken!),
      ),
    );
  }

  void _setReady(Room room) {
    if (currentUserId == null) return;

    setState(() {
      room.setReady(currentUserId!);

      if (room.allReady && currentUserId == room.hostId) {
        _startGame(room);
      }
    });
  }

  @override
  void dispose() {
    _leaveMatchmaking(); // 서버에 나감 알림
    channel.sink.close();
    super.dispose();
  }

  Future<void> _leaveMatchmaking() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    if (token == null) return;

    final url = Uri.parse("http://localhost:8080/api/game/lobby/leave");
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: '{}',
    );

    if (response.statusCode == 200) {
      print("매칭에서 나감 알림 완료");
    } else {
      print("매칭 나감 실패: ${response.statusCode}");
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 버튼 눌렀을 때 서버에 나감 알림
        await _leaveMatchmaking();

        // WebSocket 종료
        channel.sink.close();

        // true 반환하면 화면 pop 됨
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("플레이어 매칭"),
          backgroundColor: const Color(0xFF4E6E99),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: rooms.isEmpty
                    ? const Center(child: Text("현재 매칭 중인 방이 없습니다."))
                    : ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final isReady = currentUserId != null &&
                              room.readyStatus[currentUserId!] == true;

                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                  color: Color(0xFF4E6E99), width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${room.roomName} (${room.playerIds.length}/5)",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    room.playerIds.map((id) {
                                      final nickname = room.nicknames[id] ?? id;
                                      final ready =
                                          room.readyStatus[id] ?? false;
                                      return "$nickname ${ready ? '✅ 준비 완료' : '님을 ⌛ 기다리는 중..'}";
                                    }).join(", "),
                                  ),
                                  const SizedBox(height: 8),
                                  !isReady
                                      ? ElevatedButton(
                                          onPressed: () => _setReady(room),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF4E6E99),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text("준비 완료"),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "준비 완료",
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            if (room.allReady &&
                                                room.playerIds.length >= 2 &&
                                                currentUserId == room.hostId)
                                              ElevatedButton(
                                                onPressed: () =>
                                                    _startGame(room),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                                child: const Text("게임 시작"),
                                              ),
                                          ],
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
