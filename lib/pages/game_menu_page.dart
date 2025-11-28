import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'games/game2_page.dart';
import 'games/game3_page.dart';
import 'games/game4_page.dart';
import 'games/game6_page.dart';
import 'games/dummy_game_page.dart';
import 'games/matching_page.dart';
import '../bingo_game/bingo_match_page.dart';
import '../word_guess_game/guess_match_page.dart';

// -------------------- GameInfo --------------------
class GameInfo {
  final String title;
  final Widget? soloPage;
  final Widget Function(List<String>, List<String>)? multiPageBuilder;

  const GameInfo({
    required this.title,
    this.soloPage,
    this.multiPageBuilder,
  });

  bool get isSoloOnly => soloPage != null && multiPageBuilder == null;
  bool get isMultiOnly => soloPage == null && multiPageBuilder != null;
  bool get hasBoth => soloPage != null && multiPageBuilder != null;
}

// -------------------- GameMenuPage --------------------
class GameMenuPage extends StatelessWidget {
  const GameMenuPage({Key? key}) : super(key: key);

  final List<GameInfo> games = const [
    GameInfo(
      title: "단어 빨리 맞히기",
      multiPageBuilder: _speedGameMultiPage,
    ),
    GameInfo(
      title: "제시어 영작 게임",
      soloPage: Game2Page(),
    ),
    GameInfo(
      title: "미로 탈출",
      soloPage: Game3Page(),
    ),
    GameInfo(
      title: "끝말 잇기",
      soloPage: Game4Page(),
    ),
    // ✅ 수정된 부분
    GameInfo(
      title: "빙고 게임",
      multiPageBuilder: _bingoMultiPage, // ✅ 여기 바꿈!
    ),
    GameInfo(
      title: "단어 타워 쌓기",
      soloPage: Game6Page(),
    ),
  ];

  // 기존 더미용
  static Widget _dummyMultiPage(List<String> userIds, List<String> tokens) {
    return MatchingPage(
      gameWidgetBuilder: (roomId) =>
          DummyGamePage(userIds: userIds, tokens: tokens),
    );
  }

  // ✅ Speed Game 전용 빌더
  static Widget _speedGameMultiPage(List<String> userIds, List<String> tokens) {
    return const GuessMatchPage(); // 로그인 불필요 — 바로 소켓 연결
  }

  // ✅ 빙고 전용 빌더
  static Widget _bingoMultiPage(List<String> userIds, List<String> tokens) {
    return const BingoMatchPage(); // 로그인 불필요 — 바로 소켓 연결
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D4C63),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 20 / 17,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            final imagePath = "assets/images/game${index + 1}.png";
            return _gameThumbnail(
              imagePath,
              () => _onGameSelected(context, game),
              game.title,
            );
          },
        ),
      ),
    );
  }

  void _onGameSelected(BuildContext context, GameInfo game) {
    if (game.isSoloOnly) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => game.soloPage!),
      );
    } else if (game.isMultiOnly) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => game.multiPageBuilder!([], [])),
      );
    } else if (game.hasBoth) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StartPageWithModes(
            title: game.title,
            soloPage: game.soloPage!,
            multiPageBuilder: game.multiPageBuilder!,
          ),
        ),
      );
    }
  }

  Widget _gameThumbnail(String imagePath, VoidCallback onTap, String title) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- StartPageWithModes --------------------
class StartPageWithModes extends StatelessWidget {
  final String title;
  final Widget soloPage;
  final Widget Function(List<String>, List<String>) multiPageBuilder;

  const StartPageWithModes({
    super.key,
    required this.title,
    required this.soloPage,
    required this.multiPageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: Text(title),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeButton(context, "혼자 하기", (_, __) => soloPage),
            const SizedBox(width: 20),
            _modeButton(context, "같이 하기", multiPageBuilder),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(BuildContext context, String label,
      Widget Function(List<String>, List<String>) pageBuilder) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4E6E99),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        final myId = prefs.getString("user_id") ?? "unknown";
        final myToken = prefs.getString("jwt_token") ?? "";

        if (label == "같이 하기") {
          final userIds = [myId];
          final tokens = [myToken];
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => pageBuilder(userIds, tokens)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => pageBuilder([], [])),
          );
        }
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
