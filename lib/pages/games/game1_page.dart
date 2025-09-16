import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ------------------- 멀티플레이어 단어 게임 로직 -----------------
class MultiplayerFastWordGame {
  final int maxPlayers = 5;
  Map<String, List<Map<String, dynamic>>> playerWordBanks = {};
  Map<String, int> scores = {};
  Map<String, int> lives = {};
  Map<String, String?> currentWords = {};
  bool gameOver = false;
  Random random = Random();

  VoidCallback? onUpdate;

  Future<void> startGame(List<String> userIds, String token) async {
    final url = Uri.parse("http://localhost:8080/api/personal-words/for-game");
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(userIds),
    );

    if (response.statusCode == 200) {
      final List<dynamic> wordsList = jsonDecode(response.body);

      for (var word in wordsList) {
        String userId = word["userId"];
        playerWordBanks
            .putIfAbsent(userId, () => [])
            .add(Map<String, dynamic>.from(word));
      }

      for (var userId in userIds) {
        scores[userId] = 0;
        lives[userId] = 3;
        currentWords[userId] = _nextWord(userId);
      }

      onUpdate?.call();
    } else {
      throw Exception("단어 목록 가져오기 실패: ${response.statusCode}");
    }
  }

  String? _nextWord(String userId) {
    final bank = playerWordBanks[userId];
    if (bank == null || bank.isEmpty) return null;
    final word = bank[random.nextInt(bank.length)];
    return word["wordEn"];
  }

  void submitWord(String userId, String word) {
    if (gameOver || currentWords[userId] == null) return;

    word = word.toLowerCase().trim();
    String correctWord = currentWords[userId]!.toLowerCase();

    if (word != correctWord) {
      lives[userId] = (lives[userId] ?? 1) - 1;
      if (lives[userId]! <= 0) {
        currentWords[userId] = null;
      }
    } else {
      scores[userId] = (scores[userId] ?? 0) + 5;
      currentWords[userId] = _nextWord(userId);
    }

    if (lives.values.every((l) => l <= 0)) {
      gameOver = true;
    }

    onUpdate?.call();
  }
}

/// ----------------- 게임 페이지 -----------------
class Game1Page extends StatefulWidget {
  final List<String> userIds;
  final List<String> tokens;

  const Game1Page({super.key, required this.userIds, required this.tokens});

  @override
  State<Game1Page> createState() => _Game1PageState();
}

class _Game1PageState extends State<Game1Page> {
  late MultiplayerFastWordGame game;
  final Map<String, TextEditingController> controllers = {};
  final Map<String, Timer?> timers = {};
  int gameDuration = 30;

  @override
  void initState() {
    super.initState();
    game = MultiplayerFastWordGame();
    game.onUpdate = () => setState(() {});
    _fetchWordsAndStart();
  }

  Future<void> _fetchWordsAndStart() async {
    for (int i = 0; i < widget.userIds.length; i++) {
      String userId = widget.userIds[i];
      game.playerWordBanks[userId] = [
        {"wordEn": "apple"},
        {"wordEn": "banana"},
        {"wordEn": "cherry"},
      ];
      game.scores[userId] = 0;
      game.lives[userId] = 3;
      game.currentWords[userId] = game.playerWordBanks[userId]![0]["wordEn"];
      controllers[userId] = TextEditingController();
      _startPlayerTimer(userId, gameDuration);
    }
    game.onUpdate?.call();
  }

  void _startPlayerTimer(String userId, int duration) {
    int remaining = duration;
    timers[userId]?.cancel();
    timers[userId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remaining <= 0 || game.currentWords[userId] == null) {
        timer.cancel();
        game.currentWords[userId] = null;
      } else {
        remaining--;
      }
      setState(() {});
    });
  }

  void _submitWord(String userId) {
    final text = controllers[userId]?.text ?? '';
    if (text.isEmpty) return;
    game.submitWord(userId, text);
    controllers[userId]?.clear();
  }

  @override
  void dispose() {
    for (var t in timers.values) t?.cancel();
    for (var c in controllers.values) c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        title: const Text("단어 빨리 맞히기"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 2.5,
          mainAxisSpacing: 16,
        ),
        itemCount: widget.userIds.length,
        itemBuilder: (context, index) {
          final userId = widget.userIds[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("플레이어: $userId",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("현재 단어: ${game.currentWords[userId] ?? '게임 오버'}",
                    style: const TextStyle(fontSize: 18)),
                Text(
                    "점수: ${game.scores[userId] ?? 0} | 목숨: ${game.lives[userId] ?? 0}"),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controllers[userId],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "단어 입력",
                        ),
                        onSubmitted: (_) => _submitWord(userId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _submitWord(userId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4E6E99),
                      ),
                      child: const Text("제출"),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
