import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../loading_page.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

// ------------------ 날아오는 블록 ------------------
class FlyingBlock {
  static const double width = 120;
  static const double height = 60;
  double x = -width;
  double y = 400;
  double speed = 200;

  final double targetX;
  final double targetY;
  final ui.Image image; // 이미지

  bool finished = false;
  bool addedToTower = false;

  FlyingBlock({
    required this.targetX,
    required this.targetY,
    required this.image,
  });

  void update(double dt) {
    if ((x - targetX).abs() > 0.1) {
      double step = speed * dt;
      if ((x + step - targetX).abs() > (x - targetX).abs()) {
        x = targetX;
      } else {
        x += step;
      }
    }

    double dy = targetY - y;
    if (dy.abs() > 0.1) {
      y += dy * 5 * dt;
    }

    if ((x - targetX).abs() < 0.1 && (y - targetY).abs() < 0.1) {
      x = targetX;
      y = targetY;
      finished = true;
    }
  }
}

// ------------------ 게임 로직 ------------------
class Game6 extends FlameGame {
  List<FlyingBlock> flyingBlocks = [];
  List<FlyingBlock> towerBlocks = [];
  double towerX = 0;
  double towerY = 0;
  int towerHeight = 0;

  double yOffset = 0;
  double targetYOffset = 0;

  List<ui.Image> blockImages = [];
  final Random _random = Random();

  // 카메라 제어
  double cameraSpeed = 0;
  double cameraAcceleration = 20;
  double elapsedTime = 0;

  VoidCallback? onGameOut;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    final characters = [
      'assets/images/game/part6/cake1.png',
      'assets/images/game/part6/cake2.png',
      'assets/images/game/part6/cake3.png',
      'assets/images/game/part6/cake4.png',
      'assets/images/game/part6/cake5.png',
    ];

    for (var path in characters) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      blockImages.add(frame.image);
    }
  }

  void addBlockToTower() {
    double targetY;
    if (towerBlocks.isEmpty) {
      targetY = towerY;
    } else {
      targetY = towerBlocks.last.y - FlyingBlock.height + 1;
    }

    ui.Image img = blockImages[_random.nextInt(blockImages.length)];
    flyingBlocks.add(
      FlyingBlock(targetX: towerX, targetY: targetY, image: img),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    elapsedTime += dt;

    // 블록 이동
    for (var block in flyingBlocks) {
      block.update(dt);

      if (block.finished && !block.addedToTower) {
        towerBlocks.add(block);
        block.addedToTower = true;
        towerHeight++;
      }
    }

    flyingBlocks.removeWhere((b) => b.finished && b.addedToTower);

    // --- 카메라 제어 ---
    if (elapsedTime > 5) {
      // 초기 속도 낮게, 30초마다 조금씩 증가
      double initialSpeed = 15; // 처음 내려가는 속도
      double speedIncrease = 10; // 30초마다 증가하는 속도
      cameraSpeed = initialSpeed + ((elapsedTime ~/ 30) * speedIncrease);

      yOffset += cameraSpeed * dt;

      // 타워가 화면에서 완전히 사라지면 게임 종료
      if (towerBlocks.isNotEmpty) {
        double lowestBlockY = towerBlocks
            .map((b) => b.y + FlyingBlock.height)
            .reduce(max);
        if (lowestBlockY - yOffset < 0) {
          towerBlocks.clear();
          flyingBlocks.clear();
          if (onGameOut != null) onGameOut!();
        }
      }
    }

    // 기존 중심 맞춤 로직
    if (towerBlocks.length > 5) {
      double highestY = towerBlocks.map((b) => b.y).reduce(min);
      double desiredYOffset = size.y / 2 - highestY - FlyingBlock.height / 2;
      desiredYOffset = min(0, desiredYOffset);

      // 카메라가 내려가고 있을 때는 너무 강제로 yOffset 맞추지 않음
      if (desiredYOffset > yOffset) {
        yOffset += (desiredYOffset - yOffset) * dt * 2; // 천천히 올림
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _renderBackground(canvas);

    canvas.save();
    canvas.translate(0, yOffset);

    for (var block in towerBlocks) {
      final rect = Rect.fromLTWH(
        block.x,
        block.y,
        FlyingBlock.width,
        FlyingBlock.height,
      );
      canvas.drawImageRect(
        block.image,
        Rect.fromLTWH(
          0,
          0,
          block.image.width.toDouble(),
          block.image.height.toDouble(),
        ),
        rect,
        Paint(),
      );
    }

    for (var block in flyingBlocks) {
      final rect = Rect.fromLTWH(
        block.x,
        block.y,
        FlyingBlock.width,
        FlyingBlock.height,
      );
      canvas.drawImageRect(
        block.image,
        Rect.fromLTWH(
          0,
          0,
          block.image.width.toDouble(),
          block.image.height.toDouble(),
        ),
        rect,
        Paint(),
      );
    }

    canvas.restore();
  }

  void _renderBackground(Canvas canvas) {
    double skyHeight = size.y;
    Rect rect = Rect.fromLTWH(0, 0, size.x, skyHeight);

    Color topColor =
        Color.lerp(
          Color(0xFF87CEEB),
          Color(0xFF00172D),
          (-yOffset / 1000).clamp(0.0, 1.0),
        )!;
    Color bottomColor =
        Color.lerp(
          Color(0xFF4E6E99),
          Color(0xFF000010),
          (-yOffset / 1000).clamp(0.0, 1.0),
        )!;

    Paint paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, bottomColor],
          ).createShader(rect);

    canvas.drawRect(rect, paint);
  }
}

// ------------------ 게임 페이지 ------------------
class Game6Page extends StatefulWidget {
  const Game6Page({Key? key}) : super(key: key);

  @override
  State<Game6Page> createState() => _Game6PageState();
}

class _Game6PageState extends State<Game6Page> {
  List<Map<String, dynamic>> words = [];
  Map<String, dynamic>? currentWord;
  bool showKorean = true;

  final TextEditingController controller = TextEditingController();
  String? userId;
  String? token;
  bool isLoading = true;

  late Game6 game;
  final Random _random = Random();

  int totalTime = 120;
  int questionNumber = 0;
  Timer? gameTimer;
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    game = Game6();
    game.onGameOut = () {
      setState(() {
        gameOver = true;
        _showGameOverDialog();
      });
    };
    _loadUserIdAndWords();
  }

  @override
  void dispose() {
    controller.dispose();
    gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserIdAndWords() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('jwt_token');
    final storedUserId = prefs.getString('user_id');

    if (storedUserId == null || storedToken == null) {
      print("User ID 또는 Token 없음");
      setState(() => isLoading = false);
      return;
    }

    setState(() {
      userId = storedUserId;
      token = storedToken;
    });

    await fetchWords(storedUserId, storedToken);
  }

  Future<void> fetchWords(String userId, String token) async {
    final url = Uri.parse("http://localhost:8080/api/personal-words/$userId");
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      setState(() {
        words = list;
        _nextQuestion();
        isLoading = false;
      });
    } else {
      print("단어 조회 실패: ${response.statusCode}");
      setState(() => isLoading = false);
    }
  }

  void _startGameTimer() {
    gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (gameOver) {
        timer.cancel();
        return;
      }

      totalTime--;

      if (totalTime <= 0) {
        gameOver = true;
        timer.cancel();
        _showGameOverDialog();
      }

      setState(() {});
    });
  }

  void _nextQuestion() {
    if (words.isEmpty) return;
    currentWord = words[_random.nextInt(words.length)];
    showKorean = _random.nextBool();
    questionNumber++;
  }

  void checkAnswer() {
    if (currentWord == null || gameOver) return;

    final answer =
        showKorean
            ? currentWord!["wordEn"].toString().toLowerCase()
            : currentWord!["koreanMeaning"].toString().toLowerCase();

    if (controller.text.trim().toLowerCase() == answer) {
      game.addBlockToTower();
      _nextQuestion();

      // 첫 정답 입력 시 타이머 시작
      if (gameTimer == null) {
        _startGameTimer();
      }
    }

    controller.clear();
    setState(() {});
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("게임 종료"),
            content: Text("총 쌓인 블록: ${game.towerHeight}"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("확인"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingPage();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("개인 단어 타워 (솔로 모드)"),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text("총 시간: ${totalTime}s")],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            height: 80,
            width: double.infinity,
            color: Colors.black12,
            child: Center(
              child: Text(
                currentWord != null
                    ? (showKorean
                        ? currentWord!["koreanMeaning"] ?? "단어 없음"
                        : currentWord!["wordEn"] ?? "단어 없음")
                    : "단어 없음",
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double gameWidth = constraints.maxWidth;
                double gameHeight = constraints.maxHeight;

                game.towerX = (gameWidth - FlyingBlock.width) / 2;
                game.towerY = gameHeight - FlyingBlock.height;

                return ClipRect(child: GameWidget(game: game));
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "정답 입력",
              ),
              onSubmitted: (_) => checkAnswer(),
            ),
          ),
        ],
      ),
    );
  }
}
