import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'multiplayer_game_page.dart';

class MatchingPage extends StatefulWidget {
  const MatchingPage({Key? key}) : super(key: key);

  @override
  State<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends State<MatchingPage> {
  List<String> players = []; // 현재 입장한 플레이어
  final int maxPlayers = 5;

  @override
  void initState() {
    super.initState();
    _addCurrentUser(); // 현재 로그인한 유저 자동 추가
  }

  Future<void> _addCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");
    if (userId != null && !players.contains(userId)) {
      setState(() {
        players.add(userId);
      });
    }
  }

  void _joinPlayer(String userId) {
    if (players.length >= maxPlayers) return;
    if (!players.contains(userId)) {
      setState(() {
        players.add(userId);
      });
    }
  }

  void _leavePlayer(String userId) {
    setState(() {
      players.remove(userId);
    });
  }

  void _startGame() {
    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("최소 2명 이상이어야 게임을 시작할 수 있습니다.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiplayerGamePage(userIds: players),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("플레이어 매칭"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("현재 플레이어 (${players.length}/$maxPlayers)",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return ListTile(
                    title: Text(player),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _leavePlayer(player),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6E99),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("게임 시작",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
