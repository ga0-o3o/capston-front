import 'dart:async';
import 'dart:convert';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Game2 extends FlameGame {
  int score = 0;
  int timeLeft = 30;
  String currentWord = '';
  Timer? _timer;
  List<String> wordList = [];

  final String userId;
  final String token;

  Game2({required this.userId, required this.token});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    await _fetchWords();
    if (wordList.isNotEmpty) {
      _nextWord();
      _startTimer();
    }
  }

  Future<void> _fetchWords() async {
    try {
      final url = Uri.parse("http://localhost:8080/api/personal-words/$userId");
      final response =
          await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        wordList = List<String>.from(data);
      } else {
        wordList = [];
      }
    } catch (e) {
      wordList = [];
    }
  }

  void _nextWord() {
    if (wordList.isEmpty) return;
    currentWord = (wordList..shuffle()).first;
    overlays.add('inputOverlay');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timeLeft--;
      if (timeLeft <= 0) {
        timer.cancel();
        overlays.add('gameOver');
      }
    });
  }

  void checkSentence(String sentence) {
    if (sentence.toLowerCase().contains(currentWord.toLowerCase())) {
      score++;
    }
    _nextWord();
  }

  @override
  void onRemove() {
    _timer?.cancel();
    super.onRemove();
  }
}

class Game2Page extends StatefulWidget {
  const Game2Page({Key? key}) : super(key: key);

  @override
  State<Game2Page> createState() => _Game2PageState();
}

class _Game2PageState extends State<Game2Page> {
  String? userId;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId') ?? '';
      token = prefs.getString('token') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null || token == null || userId!.isEmpty || token!.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final game = Game2(userId: userId!, token: token!);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        title: const Text("제시어 영작 게임"),
        backgroundColor: const Color(0xFF4E6E99),
      ),
      body: GameWidget(
        game: game,
        overlayBuilderMap: {
          'inputOverlay': (_, Game2 game) => _InputOverlay(game: game),
          'gameOver': (_, Game2 game) => _GameOverOverlay(score: game.score),
        },
      ),
    );
  }
}

class _InputOverlay extends StatefulWidget {
  final Game2 game;
  const _InputOverlay({required this.game});

  @override
  State<_InputOverlay> createState() => _InputOverlayState();
}

class _InputOverlayState extends State<_InputOverlay> {
  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('제시어: ${widget.game.currentWord}'),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '제시어를 포함한 문장을 입력하세요',
                ),
                onSubmitted: (value) {
                  widget.game.checkSentence(value);
                  controller.clear();
                },
              ),
              Text('남은 시간: ${widget.game.timeLeft}초'),
              Text('점수: ${widget.game.score}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final int score;
  const _GameOverOverlay({required this.score});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AlertDialog(
        title: const Text('게임 종료'),
        content: Text('총 점수: $score'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
