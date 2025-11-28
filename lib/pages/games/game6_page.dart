import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import '../word/word_item.dart';
import 'game_api.dart';
import 'game_dialogs.dart';

// ------------------ 날아오는 블록 ------------------
class FlyingBlock {
  static const double width = 120;
  static const double height = 60;
  double x = -width;
  double y = 0;
  double speed = 200;

  final double targetX;
  final double targetY;
  final ui.Image image;

  bool finished = false;
  bool addedToTower = false;

  FlyingBlock({
    required this.targetX,
    required this.targetY,
    required this.image,
  });

  void update(double dt) {
    // X 이동
    if ((x - targetX).abs() > 0.1) {
      double step = 200 * dt;
      if ((x + step - targetX).abs() > (x - targetX).abs()) {
        x = targetX;
      } else {
        x += step;
      }
    }

    // Y 이동
    double dy = targetY - y;
    if (dy.abs() > 0.1) {
      y += dy * 5 * dt;
    }

    // 목표 위치 도착
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

  int pendingBlocks = 0; // 정답 입력으로 대기 중인 블록 수
  double yOffset = 0; // 카메라 이동
  List<ui.Image> blockImages = [];
  final Random _random = Random();
  double cameraSpeed = 0;
  double elapsedTime = 0;
  double startDelay = 4;
  double? firstBlockTime;

  VoidCallback? onGameOut;
  bool gameOutCalled = false; // 중복 호출 방지

  ui.Image? bgImage;

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

    // 배경 이미지 로드
    final bgData = await rootBundle.load(
      'assets/images/game/part6/background.png',
    );
    final bgBytes = bgData.buffer.asUint8List();
    final bgCodec = await ui.instantiateImageCodec(bgBytes);
    final bgFrame = await bgCodec.getNextFrame();
    bgImage = bgFrame.image;

    // 블록 이미지 모두 로드
    for (var path in characters) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      blockImages.add(frame.image);
    }

    // 모든 이미지 로딩 완료 후 초기 위치 계산
    double gameAreaHeight = 405;
    towerX = (size.x > 0 ? size.x : 360) / 2 - FlyingBlock.width / 2;
    towerY = gameAreaHeight - FlyingBlock.height;
  }

  void addBlockToTower() {
    double targetY =
        towerBlocks.isEmpty ? towerY : towerBlocks.last.y - FlyingBlock.height;

    ui.Image img = blockImages[_random.nextInt(blockImages.length)];
    double startX = size.x / 2 - FlyingBlock.width / 2 - 300;
    double startY = 0;

    flyingBlocks.add(
      FlyingBlock(targetX: towerX, targetY: targetY, image: img)
        ..x = startX
        ..y = startY,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsedTime += dt;

    for (var block in flyingBlocks) {
      block.update(dt);
      if (block.finished && !block.addedToTower) {
        towerBlocks.add(block);
        block.addedToTower = true;
        towerHeight++;

        if (firstBlockTime == null) firstBlockTime = elapsedTime;
      }
    }

    flyingBlocks.removeWhere((b) => b.finished && b.addedToTower);

    if (flyingBlocks.isEmpty && pendingBlocks > 0) {
      pendingBlocks--;
      addBlockToTower();
    }

    // 카메라 이동
    if (firstBlockTime != null &&
        (elapsedTime - firstBlockTime!) > startDelay) {
      double initialSpeed = 15;
      double speedIncrease = 10;
      cameraSpeed = initialSpeed + ((elapsedTime ~/ 30) * speedIncrease);
      yOffset += cameraSpeed * dt;
    }

    // 화면 중앙 맞춤
    if (towerBlocks.length > 5) {
      double highestY = towerBlocks.map((b) => b.y).reduce(min);
      double desiredYOffset = size.y / 2 - highestY - FlyingBlock.height / 2;
      desiredYOffset = min(0, desiredYOffset);

      if (desiredYOffset > yOffset) {
        yOffset += (desiredYOffset - yOffset) * dt * 2;
      }
    }

    // ------------------ 게임 오버 조건 ------------------
    if (!gameOutCalled && towerBlocks.isNotEmpty) {
      double highestBlockTop =
          towerBlocks.map((b) => b.y + yOffset).reduce(min);
      double bottomLimit = 450; // 화면 기준

      if (highestBlockTop > bottomLimit) {
        gameOutCalled = true;
        if (onGameOut != null) onGameOut!();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _renderBackground(canvas);

    Rect gameArea = Rect.fromLTWH(0, 0, size.x, 500);
    canvas.save();
    canvas.clipRect(gameArea);
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
    if (bgImage == null) return;

    double screenHeight = 500;
    double bgWidth = size.x;

    // background.png 높이
    double bgHeight =
        bgImage!.height.toDouble() * (bgWidth / bgImage!.width.toDouble());

    // 배경 위치
    double bgY = screenHeight - bgHeight + yOffset - 55;

    canvas.drawImageRect(
      bgImage!,
      Rect.fromLTWH(
        0,
        0,
        bgImage!.width.toDouble(),
        bgImage!.height.toDouble(),
      ),
      Rect.fromLTWH(0, bgY, bgWidth, bgHeight),
      Paint(),
    );
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
  int lives = 3; // 목숨

  bool showStartMessage = true; // 1번 안내문
  bool showSpeedUpMessage = false; // 2번 안내문

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

    _loadUserWords();

    // 1번 안내문 5초
    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        showStartMessage = false;
        showSpeedUpMessage = true; // 2번 안내문 시작
      });

      // 2번 안내문 3초 후 사라짐
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          showSpeedUpMessage = false;
        });
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    gameTimer?.cancel();
    super.dispose();
  }

  DateTime? pauseStart;

  void _pauseGame() {
    gameTimer?.cancel(); // 타이머 일시정지

    showPauseDialog(
      context: context,
      onResume: () {
        _startGameTimer(); // 타이머 그대로 재개
      },
      onExit: () {
        Navigator.pop(context); // 게임 화면 종료
      },
    );
  }

  Future<void> _loadUserWords() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('jwt_token');
    final storedUserId = prefs.getString('user_id');

    if (storedUserId == null || storedToken == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() {
      userId = storedUserId;
      token = storedToken;
    });

    try {
      print("단어 조회 시작...");
      List<WordItem> wordItems = await GameApi.fetchAllWords(storedUserId);
      print("총 ${wordItems.length}개의 단어 조회 완료");

      // ✅ wordEn 기준으로 그룹화
      Map<String, Set<String>> grouped = {};
      for (var w in wordItems) {
        final en = w.word.trim();
        final krList = w.wordKr
            .expand((k) => k.split(',')) // "배, U 보트" → ["배", "U 보트"]
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty);

        if (!grouped.containsKey(en)) grouped[en] = {};
        grouped[en]!.addAll(krList);
      }

      // ✅ 합쳐진 데이터로 변환
      List<Map<String, dynamic>> allWords = grouped.entries.map((entry) {
        return {
          "wordEn": entry.key,
          "wordKr": entry.value.join(', '), // 예: "배, U 보트"
        };
      }).toList();

      setState(() {
        words = allWords;
        isLoading = false;
      });

      if (words.isNotEmpty) _nextQuestion(); // ⚡ setState 바깥에서 호출
    } catch (e) {
      print("❌ 단어 조회 실패: $e");
      setState(() => isLoading = false);
    }
  }

  void _startGameTimer() {
    if (gameTimer != null && gameTimer!.isActive) return; // 이미 진행 중이면 무시

    gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (gameOver) {
        timer.cancel();
        return;
      }

      totalTime--;

      if (totalTime <= 0) {
        gameOver = true;
        timer.cancel();

        // 성공 조건: 목숨이 남아있고 블록이 화면 아래로 내려가지 않은 경우
        bool success = lives > 0 &&
            !(game.towerBlocks.isNotEmpty &&
                game.towerBlocks.map((b) => b.y + game.yOffset).reduce(min) >
                    450);

        _showGameOverDialog(success: success);
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

  bool timerStarted = false; // 클래스 필드

  void checkAnswer() {
    if (currentWord == null || gameOver) return;

    final userInput = controller.text.trim().toLowerCase();

    if (showKorean) {
      // 한국어 → 영어 맞추기
      final correctAnswer = currentWord!["wordEn"].toString().toLowerCase();
      if (userInput == correctAnswer) {
        _handleCorrect();
      } else {
        _handleWrong();
      }
    } else {
      // 영어 → 한국어 맞추기
      final allAnswers = currentWord!["wordKr"]
          .toString()
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      if (allAnswers.contains(userInput)) {
        _handleCorrect();
      } else {
        _handleWrong();
      }
    }

    controller.clear();
    setState(() {});
  }

// ✅ 정답 / 오답 공통 처리 함수
  void _handleCorrect() {
    if (game.flyingBlocks.isEmpty) {
      game.addBlockToTower();
    } else {
      game.pendingBlocks++;
    }
    _nextQuestion();

    if (!timerStarted) {
      _startGameTimer();
      timerStarted = true;
    }
  }

  void _handleWrong() {
    lives--;
    if (lives <= 0) {
      gameOver = true;
      _showGameOverDialog();
    }
  }

  void _showGameOverDialog({bool success = false}) {
    showGameOverDialog_game6(
      context: context,
      success: success,
      towerHeight: game.towerHeight,
      onConfirm: () {
        Navigator.pop(context); // 게임 화면 종료 → 이전 화면으로 돌아감
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("단어 타워 쌓기"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // 위쪽 정렬
          children: [
            // 총 시간
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("남은 시간: ${totalTime}s"),
                Row(
                  children: List.generate(
                    lives,
                    (index) => const Icon(Icons.favorite, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 문제 영역
            Container(
              padding: const EdgeInsets.all(16),
              height: 80,
              width: double.infinity,
              color: Colors.black12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        currentWord != null
                            ? (showKorean
                                ? currentWord!["wordKr"] ?? " "
                                : currentWord!["wordEn"] ?? " ")
                            : " ",
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.pause,
                      color: Colors.black87,
                      size: 28,
                    ),
                    // 1번 안내문, 2번 안내문이 모두 끝나야만 작동
                    onPressed: (!showStartMessage && !showSpeedUpMessage)
                        ? _pauseGame
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 게임 영역
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRect(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          border: Border.all(color: Colors.black, width: 5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GameWidget(game: game),
                      ),
                    ),
                    if (showStartMessage) ...[
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withOpacity(0.7),
                        alignment: Alignment.center,
                        child: const Text(
                          "준비하세요!\n게임이 곧 시작됩니다. \n문제를 맞추면 탑이 쌓여집니다.\n탑이 완전히 화면에서 사라지거나 \n목숨을 다 사용하면 게임 오버!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (showSpeedUpMessage) ...[
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withOpacity(0.7),
                        alignment: Alignment.center,
                        child: const Text(
                          "30초마다 올라가는 속도가 빨라집니다!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // ------------------ 정답 입력창 + 제출 버튼 ------------------
            Row(
              children: [
                // 입력창
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "정답 입력",
                    ),
                    onSubmitted: (!showStartMessage && !showSpeedUpMessage)
                        ? (_) => checkAnswer()
                        : null,
                    enabled: !showStartMessage && !showSpeedUpMessage,
                  ),
                ),
                const SizedBox(width: 8),
                // 제출 버튼
                ElevatedButton(
                  onPressed: (!showStartMessage && !showSpeedUpMessage)
                      ? checkAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6E99),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Text("제출"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
