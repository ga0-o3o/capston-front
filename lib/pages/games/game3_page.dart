import 'dart:async' as async;
import 'dart:math';
import 'package:flame/game.dart';
import '../game_menu_page.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_api.dart';
import 'game_dialogs.dart';
import '../word/word_item.dart';

// -------------------- Maze Game --------------------
class MazeGame extends FlameGame {
  late Maze maze;
  late Player player;
  bool initialized = false;

  int timeLeft = 140;
  int lives = 3;
  bool gameOver = false;

  bool canMove = true;
  Vector2? currentDirection; // ✅ 현재 선택된 방향
  VoidCallback? onUpdate;
  Random random = Random();

  @override
  Future<void> onLoad() async {
    super.onLoad();
    final screenSize = size;
    int rows = 15;
    int cols = 16;

    double tileW = screenSize.x / cols;
    double tileH = screenSize.y / rows;
    Maze.tileSize = min(tileW, tileH);

    maze = Maze(rows, cols);
    player = Player(position: maze.startPosition, maze: maze);
    add(maze);
    add(player);

    initialized = true;
  }

  void movePlayer(Vector2 dir) {
    if (!canMove) return;

    // ✅ 선택된 방향이 있으면 그 방향만 허용
    if (currentDirection != null && dir != currentDirection) {
      return;
    }

    Vector2 newPos = player.gridPos + dir;
    if (!maze.isWalkable(newPos)) return;

    player.moveTo(newPos);

    // 도착 체크
    if (player.gridPos == maze.endPosition) {
      canMove = false;
      gameOver = true;
      if (onUpdate != null) onUpdate!();
    }

    // 갈림길 체크
    if (maze.isAtJunction(player.gridPos, player.lastMoveDir)) {
      canMove = false;
      if (onUpdate != null) onUpdate!();
    }

    // onUpdate 호출 추가
    if (onUpdate != null) onUpdate!();

    if (player.gridPos == maze.endPosition) {
      canMove = false;
      gameOver = true;
    }
  }
}

// -------------------- Maze --------------------
class Maze extends PositionComponent {
  final int rows, cols;
  late List<List<int>> grid;
  final Vector2 startPosition = Vector2(0, 0);
  final Vector2 endPosition;

  static double tileSize = 32;

  Maze(this.rows, this.cols) : endPosition = Vector2.zero() {
    grid = List.generate(rows, (_) => List.filled(cols, 0));
    generateMaze();
  }

  void generateMaze() {
    List<List<int>> visited = List.generate(rows, (_) => List.filled(cols, 0));

    void dfs(int x, int y) {
      visited[y][x] = 1;
      grid[y][x] = 1;

      List<Vector2> dirs = [
        Vector2(0, -1),
        Vector2(0, 1),
        Vector2(-1, 0),
        Vector2(1, 0),
      ]..shuffle(Random());

      for (var d in dirs) {
        int nx = x + d.x.toInt() * 2;
        int ny = y + d.y.toInt() * 2;
        if (nx >= 0 &&
            nx < cols &&
            ny >= 0 &&
            ny < rows &&
            visited[ny][nx] == 0) {
          grid[y + d.y.toInt()][x + d.x.toInt()] = 1;
          dfs(nx, ny);
        }
      }
    }

    dfs(0, 0);

    for (int y = rows - 1; y >= 0; y--) {
      for (int x = cols - 1; x >= 0; x--) {
        if (grid[y][x] == 1) {
          endPosition.setValues(x.toDouble(), y.toDouble());
          return;
        }
      }
    }
  }

  bool isWalkable(Vector2 pos) {
    if (pos.x < 0 || pos.y < 0 || pos.x >= cols || pos.y >= rows) return false;
    return grid[pos.y.toInt()][pos.x.toInt()] == 1;
  }

  bool isAtJunction(Vector2 pos, [Vector2? lastDir]) {
    List<Vector2> dirs = [
      Vector2(0, -1),
      Vector2(0, 1),
      Vector2(-1, 0),
      Vector2(1, 0),
    ];

    int walkableCount = 0;
    bool wallAhead = false;

    for (var d in dirs) {
      Vector2 next = pos + d;
      if (isWalkable(next)) walkableCount++;
      if (lastDir != null && d == lastDir && !isWalkable(next))
        wallAhead = true;
    }

    return walkableCount >= 3 || (walkableCount >= 2 && wallAhead);
  }

  @override
  void render(Canvas canvas) {
    final paintWall = Paint()..color = Colors.black;
    final paintPath = Paint()..color = Colors.white;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * tileSize, y * tileSize, tileSize, tileSize),
          grid[y][x] == 1 ? paintPath : paintWall,
        );
      }
    }

    final startPaint = Paint()..color = Colors.green;
    canvas.drawRect(
      Rect.fromLTWH(
        startPosition.x * tileSize,
        startPosition.y * tileSize,
        tileSize,
        tileSize,
      ),
      startPaint,
    );

    final endPaint = Paint()..color = Colors.red;
    canvas.drawRect(
      Rect.fromLTWH(
        endPosition.x * tileSize,
        endPosition.y * tileSize,
        tileSize,
        tileSize,
      ),
      endPaint,
    );
  }
}

// -------------------- Player --------------------
class Player extends PositionComponent {
  Vector2 gridPos;
  final Maze maze;
  Vector2 lastMoveDir = Vector2.zero();

  Player({required Vector2 position, required this.maze})
      : gridPos = position.clone() {
    size = Vector2(Maze.tileSize, Maze.tileSize);
    this.position = gridPos * Maze.tileSize;
  }

  void moveTo(Vector2 newGridPos) {
    if ((newGridPos - gridPos).x.abs() + (newGridPos - gridPos).y.abs() != 1)
      return;
    lastMoveDir = newGridPos - gridPos;
    gridPos = newGridPos.clone();
    position = gridPos * Maze.tileSize; // 실제 화면 위치 갱신
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}

// -------------------- Maze Extensions --------------------
extension MazeExtensions on Maze {
  bool isDeadEnd(Vector2 pos) {
    List<Vector2> dirs = [
      Vector2(0, -1),
      Vector2(0, 1),
      Vector2(-1, 0),
      Vector2(1, 0),
    ];

    int walkableCount = 0;
    for (var d in dirs) {
      if (isWalkable(pos + d)) walkableCount++;
    }

    return walkableCount == 1; // 통로가 하나만 남으면 막다른 길
  }
}

// -------------------- Direction Selection Dialog --------------------
class DirectionSelectionDialog extends StatefulWidget {
  final void Function(Vector2 dir) onSelect;

  const DirectionSelectionDialog({super.key, required this.onSelect});

  @override
  State<DirectionSelectionDialog> createState() =>
      _DirectionSelectionDialogState();
}

class _DirectionSelectionDialogState extends State<DirectionSelectionDialog> {
  late List<Map<String, dynamic>> directions;
  async.Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    directions = [
      {"dir": Vector2(0, -1), "label": "위쪽"},
      {"dir": Vector2(-1, 0), "label": "왼쪽"},
      {"dir": Vector2(1, 0), "label": "오른쪽"},
      {"dir": Vector2(0, 1), "label": "아래쪽"},
    ];

    // 3초 후 자동 닫기
    _autoCloseTimer = async.Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dialog 닫기
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    directions.shuffle(); // 매번 섞기

    return AlertDialog(
      title: const Text("방향 선택"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("이동할 방향을 선택하세요"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: directions.map((d) {
              return ElevatedButton(
                onPressed: () {
                  _autoCloseTimer?.cancel(); // 사용자가 선택하면 타이머 취소
                  Navigator.pop(context, d["dir"] as Vector2);
                },
                child: Text(d["label"] as String),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// -------------------- Game Page --------------------
class Game3Page extends StatefulWidget {
  const Game3Page({Key? key}) : super(key: key);

  @override
  State<Game3Page> createState() => _Game3PageState();
}

class _Game3PageState extends State<Game3Page> {
  List<Map<String, dynamic>> words = [];
  late MazeGame game;
  async.Timer? timer;
  final TextEditingController controller = TextEditingController();
  final FocusNode gameFocusNode = FocusNode(); // 게임 화면용 포커스
  final FocusNode answerFocusNode = FocusNode(); // 입력창용 포커스

  Map<String, dynamic>? currentWord;
  bool showQuestion = false;
  bool showInfoMessage = false;
  String infoMessage = "";

  bool showIntro = true;
  bool hasMoved = false;

  int totalTime = 140;
  int lives = 3;
  final Random _random = Random();

  bool showEnglish = true;

  int solvedQuestions = 0; // 풀었던 문제 수

  bool showDirectionButtons = false; // 방향 선택 버튼 표시 여부
  async.Timer? directionTimer; // 3초 타이머

  String? userId;
  String? token;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    game = MazeGame();

    // ✅ 5초 뒤 안내 숨기고 그때 타이머 시작
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => showIntro = false);
        startTimer();
      }
    });

    game.onUpdate = () {
      if (!mounted) return;
      setState(() {
        if (game.player.gridPos == game.maze.endPosition) {
          showInfoMessage = true;
          infoMessage = "🎉 미로 탈출 성공! 🎉";
          showQuestion = false;
          game.gameOver = true;
          _checkGameOver();
        } else if (game.maze.isAtJunction(
          game.player.gridPos,
          game.player.lastMoveDir,
        )) {
          showInfoMessage = true;
          infoMessage = "방향을 바꾸고 싶다면, 문제를 풀어야 합니다.";
          showQuestion = true;
          game.canMove = false;
        } else if (game.maze.isDeadEnd(game.player.gridPos)) {
          showInfoMessage = true;
          infoMessage = "🚧 막다른 길입니다! 문제를 풀고 방향을 선택하세요.";
          showQuestion = true;
          game.canMove = false;
        }
      });
    };

    _loadUserWords();
  }

  void _checkGameOver() {
    if (!game.gameOver) return;

    Future.delayed(Duration.zero, () {
      showGameOverDialog_game3(
        context: context,
        remainingLives: lives,
        remainingTime: totalTime,
        solvedQuestions: solvedQuestions,
        onConfirm: () {
          Navigator.of(context).pop(); // 다이얼로그 닫기
          Navigator.of(context).pop(); // 게임 페이지 pop → 이전 페이지로 이동
        },
      );
    });
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

      // 게임에서 사용할 Map 형태로 변환
      List<Map<String, dynamic>> allWords = wordItems.map((w) {
        return {
          "wordEn": w.word,
          "wordKr": w.wordKr.isNotEmpty ? w.wordKr.first : "",
        };
      }).toList();

      setState(() {
        words = allWords;
        if (words.isNotEmpty) _nextQuestion();
        isLoading = false;
      });
    } catch (e) {
      print("❌ 단어 조회 실패: $e");
      setState(() => isLoading = false);
    }
  }

  void startTimer() {
    timer = async.Timer.periodic(const Duration(seconds: 1), (t) {
      if (totalTime > 0 && !game.gameOver) {
        setState(() => totalTime--);
        game.timeLeft = totalTime;
      } else {
        t.cancel();
        game.gameOver = true; // ⬅️ 게임 오버
        setState(() {
          showInfoMessage = true;
          infoMessage = "⏰ 시간 종료! 게임 오버!";
        });
        _checkGameOver();
      }
    });
  }

  void _nextQuestion() {
    if (words.isEmpty) {
      setState(() => currentWord = null);
      return;
    }

    setState(() {
      currentWord = words[_random.nextInt(words.length)];
      showEnglish = _random.nextBool();
      showQuestion = true;

      // 갈림길 문제일 때만 이동 금지
      if (game.maze.isAtJunction(
        game.player.gridPos,
        game.player.lastMoveDir,
      )) {
        game.canMove = false;
      } else {
        game.canMove = true; // 일반 통로에서는 자유롭게 이동
      }
    });
  }

  Future<void> onMove(Vector2 dir) async {
    if (game.gameOver) return;

    // ✅ 최초 움직임 체크
    if (!hasMoved) {
      setState(() {
        hasMoved = true;
      });
    }

    game.movePlayer(dir);
  }

  Future<bool> showQuestionDialog() async {
    if (currentWord == null) return false;
    String word = currentWord?["wordEn"] ?? "";
    currentWord!["koreanMeaning"].toString().toLowerCase();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("영어 문제!"),
            content: Text("정답 단어: $word"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("정답"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("오답"),
              ),
            ],
          ),
        ) ??
        false;
  }

  // 방향 선택 처리
  Future<void> _showDirectionButtons(Vector2 currentPos) async {
    if (!showDirectionButtons) return;

    Vector2? selectedDir;

    // 3초 제한 타이머
    directionTimer = async.Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      setState(() {
        showDirectionButtons = false;
        showInfoMessage = true;
        infoMessage = '⏰ 3초 안에 방향을 선택하지 못했습니다. 문제를 다시 푸세요!';
        showQuestion = true;
        game.canMove = false;
      });

      // 새로운 문제 생성
      _nextQuestion();

      // Navigator.pop을 별도 microtask로 예약
      Future.delayed(Duration.zero, () {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop(); // Dialog 강제 닫기
        }
      });
    });

    // ✅ 선택 시에만 취소
    Vector2? dir = await showDialog<Vector2>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DirectionSelectionDialog(
        onSelect: (d) => Navigator.pop(context, d),
      ),
    );

    directionTimer?.cancel(); // ✅ 사용자가 선택했으면 타이머 취소

    if (dir != null && game.maze.isWalkable(currentPos + dir)) {
      game.currentDirection = dir;
      game.canMove = true;
      game.movePlayer(dir);

      _nextQuestion();
      setState(() {
        showQuestion = true;
        showInfoMessage = false;
        showDirectionButtons = false; // 한 번 선택했으므로 버튼 숨기기
      });
    } else {
      setState(() {
        infoMessage = "❌ 3초 안에 방향을 선택하지 못하였군요. 문제를 다시 풀어주세요!";
        showInfoMessage = true;
        showQuestion = true;
        game.canMove = false;
        showDirectionButtons = false;
      });
      _nextQuestion();
    }
  }

  void checkAnswer() {
    if (currentWord == null || game.gameOver) return;

    solvedQuestions++; // 문제 시도 시 증가

    final userAnswer = controller.text.trim().toLowerCase();
    final correctAnswer = showEnglish
        ? currentWord!["koreanMeaning"].toString().toLowerCase()
        : currentWord!["wordEn"].toString().toLowerCase();

    // checkAnswer() 내 정답 처리
    if (userAnswer == correctAnswer) {
      setState(() {
        showQuestion = false;
        infoMessage = '정답입니다! 나아갈 방향을 선택하세요.';
        showDirectionButtons = true;
        showInfoMessage = true;
        game.canMove = false;
      });

      // ✅ 정답 처리 후 새로운 문제 선택
      _nextQuestion();

      // 방향 선택 1회만
      Future.delayed(Duration.zero, () async {
        Vector2? dir = await showDialog<Vector2>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DirectionSelectionDialog(
            onSelect: (d) => Navigator.pop(context, d),
          ),
        );

        if (dir != null && game.maze.isWalkable(game.player.gridPos + dir)) {
          game.currentDirection = dir;
          game.canMove = true;
          game.movePlayer(dir);

          _nextQuestion();
          setState(() {
            showQuestion = true;
            showInfoMessage = false;
            showDirectionButtons = false; // 한 번 선택했으므로 버튼 숨기기
          });
        } else {
          setState(() {
            infoMessage = "❌ 3초 안에 선택하지 못하였군요. 문제를 다시 풀어주세요!";
            showInfoMessage = true;
            showQuestion = true;
            game.canMove = false;
            showDirectionButtons = false;
          });
        }
      });
    } else {
      // 오답 처리
      lives--;
      game.lives = lives;

      if (lives <= 0) {
        game.gameOver = true;
        setState(() {
          infoMessage = "💀 목숨 모두 소진! 게임 오버!";
          showInfoMessage = true;
        });
        _checkGameOver();
      } else {
        setState(() {
          infoMessage = '틀렸습니다! 남은 목숨: $lives';
          showInfoMessage = true;
        });

        // 오답 처리 시 새로운 문제 선택
        _nextQuestion();
      }
    }

    controller.clear();
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    gameFocusNode.dispose(); // ✅ 해제
    answerFocusNode.dispose(); // ✅ 해제
    super.dispose();
  }

  DateTime? pauseStart;

  void _pauseGame() {
    timer?.cancel(); // 타이머 일시정지

    showPauseDialog(
      context: context,
      onResume: () {
        startTimer(); // 타이머 그대로 재개
      },
      onExit: () {
        Navigator.pop(context); // 게임 화면 종료
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("미로 탈출"),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: List.generate(game.lives, (index) {
                return const Icon(Icons.favorite, color: Colors.red);
              }),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 안내문 박스
            if (showInfoMessage)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ), // 위아래 여백 줄임
                margin: const EdgeInsets.only(bottom: 8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Text(
                  infoMessage,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // 문제 박스 + 시간 + 일시정지 버튼
            Container(
              padding: const EdgeInsets.all(16),
              height: 70,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black12),
              child: Row(
                children: [
                  // 남은 시간
                  Text("남은 시간: ${totalTime}s"),
                  const SizedBox(width: 16),

                  // 문제 텍스트
                  Expanded(
                    child: Center(
                      child: game.initialized &&
                              (hasMoved &&
                                  (game.maze.isAtJunction(
                                        game.player.gridPos,
                                        game.player.lastMoveDir,
                                      ) ||
                                      game.maze.isDeadEnd(
                                        game.player.gridPos,
                                      )))
                          ? (currentWord == null
                              ? const Text("단어 없음")
                              : Text(
                                  currentWord!["wordEn"] ?? "단어 없음",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ))
                          : Container(
                              width: 100,
                              height: 50,
                              color: Colors.white,
                            ),
                    ),
                  ),

                  // 일시정지 버튼
                  IconButton(
                    icon: const Icon(
                      Icons.pause,
                      color: Colors.black87,
                      size: 28,
                    ),
                    onPressed: _pauseGame,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // -------------------- 게임 화면 --------------------
            Expanded(
              child: Stack(
                children: [
                  // 1️⃣ 게임화면 (GestureDetector ~ GameWidget)
                  GestureDetector(
                    onTap: () {
                      FocusScope.of(context).requestFocus(gameFocusNode);
                    },
                    child: Focus(
                      focusNode: gameFocusNode,
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          Vector2 dir = Vector2.zero();
                          switch (event.logicalKey.keyLabel) {
                            case 'Arrow Up':
                              dir = Vector2(0, -1);
                              break;
                            case 'Arrow Down':
                              dir = Vector2(0, 1);
                              break;
                            case 'Arrow Left':
                              dir = Vector2(-1, 0);
                              break;
                            case 'Arrow Right':
                              dir = Vector2(1, 0);
                              break;
                          }
                          if (dir != Vector2.zero()) {
                            onMove(dir); // ✅ 플레이어 이동 함수 호출
                            return KeyEventResult.handled; // 이벤트 처리 완료
                          }
                        }
                        return KeyEventResult.ignored; // 다른 키는 무시
                      },
                      child: ClipRect(
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
                    ),
                  ),

                  // 2️⃣ ✅ 시작 안내 오버레이 (문제 박스까지 전부 가림)
                  if (showIntro)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.9), // ← 흰색으로 반투명 덮기
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "미로를 탈출합시다!\n빨간 지점까지 이동하세요!\n"
                                  "미로를 선택하면 캐릭터를 움직일 수 있습니다.\n"
                                  "갈림길마다 문제를 풀고 \n방향을 선택하세요!\n"
                                  "방향 선택을 3초 안에 결정하지 않으면 \n다시 문제를 풀어야 합니다.",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  "⏳ 시간 제한 또는 ❤️ 목숨이 \n모두 사라지면 게임 오버됩니다.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 입력창
            // 입력창 + 제출 버튼
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: answerFocusNode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "정답 입력",
                    ),
                    onSubmitted: (_) {
                      checkAnswer();
                      FocusScope.of(context).requestFocus(gameFocusNode);
                    },
                  ),
                ),
                const SizedBox(width: 8), // TextField와 버튼 사이 여백
                ElevatedButton(
                  onPressed: () {
                    checkAnswer();
                    FocusScope.of(context).requestFocus(gameFocusNode);
                  },
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
            ),
          ],
        ),
      ),
    );
  }
}
