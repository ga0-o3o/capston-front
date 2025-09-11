import 'dart:async' as async;
import 'dart:math';
import 'dart:convert';
import 'package:flame/game.dart';
import '../game_menu_page.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// -------------------- Maze Game --------------------
class MazeGame extends FlameGame {
  late Maze maze;
  late Player player;
  bool initialized = false;

  int timeLeft = 180;
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
    int rows = 26;
    int cols = 27;

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

// -------------------- Direction Selection Dialog --------------------
class DirectionSelectionDialog extends StatefulWidget {
  final void Function(Vector2 dir) onSelect;

  const DirectionSelectionDialog({super.key, required this.onSelect});

  @override
  State<DirectionSelectionDialog> createState() =>
      _DirectionSelectionDialogState();
}

class _DirectionSelectionDialogState extends State<DirectionSelectionDialog> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        print("타이머 종료, Navigator.pop 호출");
        Navigator.pop(context, null); // 3초 안에 선택 안 하면 null 반환
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("방향 선택"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("이동할 방향을 선택하세요"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, Vector2(0, -1)),
                child: const Text("위쪽"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, Vector2(-1, 0)),
                child: const Text("왼쪽"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, Vector2(1, 0)),
                child: const Text("오른쪽"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, Vector2(0, 1)),
                child: const Text("아래쪽"),
              ),
            ],
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
  final FocusNode gameFocusNode = FocusNode(); // ✅ 게임 화면용 포커스
  final FocusNode answerFocusNode = FocusNode(); // 입력창용 포커스

  Map<String, dynamic>? currentWord;
  bool showQuestion = false;
  bool showInfoMessage = false;
  String infoMessage = "";

  int totalTime = 180;
  int lives = 3;
  final Random _random = Random();

  bool showEnglish = true;

  bool showDirectionButtons = false; // 방향 선택 버튼 표시 여부
  async.Timer? directionTimer; // 3초 타이머

  String? userId;
  String? token;

  @override
  void initState() {
    super.initState();
    game = MazeGame();
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
        }
      });
    };

    _loadUserIdAndWords();

    startTimer();
  }

  void _checkGameOver() {
    if (!game.gameOver) return;

    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => AlertDialog(
              title: const Text("게임 종료"),
              content: Text("남은 목숨: $lives, 남은 시간: $totalTime초"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameMenuPage(),
                      ),
                      (route) => false, // 기존의 모든 라우트 제거
                    );
                  },
                  child: const Text("확인"),
                ),
              ],
            ),
      );
    });
  }

  Future<void> _loadUserIdAndWords() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('jwt_token');
    final storedUserId = prefs.getString('user_id');

    if (storedUserId == null || storedToken == null) {
      setState(() {});
      return;
    }

    userId = storedUserId;
    token = storedToken;

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
      });
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
    game.movePlayer(dir);
  }

  Future<bool> showQuestionDialog() async {
    if (currentWord == null) return false;
    String word = currentWord?["wordEn"] ?? "";
    currentWord!["koreanMeaning"].toString().toLowerCase();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => AlertDialog(
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

    Vector2? selectedDir = await showDialog<Vector2>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => DirectionSelectionDialog(
            onSelect: (dir) => Navigator.pop(context, dir),
          ),
    );

    if (selectedDir != null) {
      if (game.maze.isWalkable(currentPos + selectedDir)) {
        directionTimer?.cancel();
        game.movePlayer(selectedDir);

        // 방향 선택 후 자유 이동 허용
        game.canMove = true;

        setState(() {
          showDirectionButtons = false;
          showInfoMessage = false;
        });
        _nextQuestion(); // 다음 문제
      } else {
        // 잘못된 방향 선택
        setState(() {
          showDirectionButtons = false;
          showInfoMessage = true;
          infoMessage = '잘못된 방향입니다! 다시 문제를 풀어주세요.';
          showQuestion = true;
        });
      }
    }
  }

  void checkAnswer() {
    if (currentWord == null || game.gameOver) return;

    final userAnswer = controller.text.trim().toLowerCase();

    final correctAnswer =
        showEnglish
            ? currentWord!["koreanMeaning"].toString().toLowerCase()
            : currentWord!["wordEn"].toString().toLowerCase();

    if (userAnswer == correctAnswer) {
      setState(() {
        showQuestion = false;
        infoMessage = '정답입니다! 나아갈 방향을 선택하세요.';
        showInfoMessage = true;
        game.canMove = false;
      });

      Future.delayed(Duration.zero, () async {
        Vector2? dir = await Future.any([
          showDialog<Vector2>(
            context: context,
            barrierDismissible: false,
            builder:
                (_) => DirectionSelectionDialog(
                  onSelect: (d) => Navigator.pop(context, d),
                ),
          ),
          Future.delayed(const Duration(seconds: 3), () => null),
        ]);

        if (dir != null) {
          // ✅ 방향 확정
          game.currentDirection = dir;
          game.canMove = true;

          // 첫 칸 이동
          game.movePlayer(dir);

          _nextQuestion();
          setState(() {
            showQuestion = true;
            showInfoMessage = false;
          });
        } else {
          setState(() {
            infoMessage = "⏰ 3초 안에 방향을 선택하지 못했습니다. 문제를 다시 푸세요!";
            showInfoMessage = true;
            showQuestion = true;
            game.canMove = false;
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
    timer?.cancel(); // 타이머 멈춤
    pauseStart = DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("일시정지"),
            content: const Text("게임을 계속하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () {
                  if (pauseStart != null) {
                    int pausedSeconds =
                        DateTime.now().difference(pauseStart!).inSeconds;
                    setState(() {
                      totalTime -= pausedSeconds; // 남은 시간 보정
                      game.timeLeft = totalTime;
                    });
                  }
                  pauseStart = null;
                  Navigator.pop(context);

                  // 타이머 재개
                  startTimer();
                },
                child: const Text("계속하기"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // 메뉴로 나가기
                },
                child: const Text("종료"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("미로 탈출"),
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

            // 문제 박스
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
                      child:
                          game.initialized &&
                                  game.maze.isAtJunction(
                                    game.player.gridPos,
                                    game.player.lastMoveDir,
                                  )
                              ? (currentWord == null
                                  ? const Text("단어 없음")
                                  : Text(
                                    showEnglish
                                        ? currentWord!["wordEn"] ?? "단어 없음"
                                        : currentWord!["koreanMeaning"] ??
                                            "뜻 없음",
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ))
                              : Container(
                                width: 100,
                                height: 80,
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
                    onPressed: () {
                      _pauseGame();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 게임 화면
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // 게임 화면 클릭 시 포커스를 게임으로 돌림
                  FocusScope.of(context).requestFocus(gameFocusNode);
                },
                child: Focus(
                  focusNode: gameFocusNode,
                  autofocus: true, // 시작할 때도 자동 포커스
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
                        onMove(dir);
                        return KeyEventResult.handled; // 이벤트 처리됨 표시
                      }
                    }
                    return KeyEventResult.ignored;
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
            ),

            const SizedBox(height: 16),

            // 입력창
            TextField(
              controller: controller,
              focusNode: answerFocusNode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "정답 입력",
              ),
              onSubmitted: (_) {
                checkAnswer();
                FocusScope.of(
                  context,
                ).requestFocus(gameFocusNode); // ✅ 자동으로 다시 게임으로
              },
            ),
          ],
        ),
      ),
    );
  }
}
