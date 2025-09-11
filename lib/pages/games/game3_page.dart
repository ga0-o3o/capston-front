import 'dart:async' as async;
import 'dart:math';
import 'dart:convert';
import 'package:flame/game.dart';
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

  int timeLeft = 180; // 제한 시간
  int lives = 3;
  bool gameOver = false;

  bool canMove = true;
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
    // 플레이어가 갈림길에서 방향 선택 전이면 이동 금지
    if (!canMove) return;

    Vector2 newPos = player.gridPos + dir;
    if (!maze.isWalkable(newPos)) return;

    player.moveTo(newPos);

    // 갈림길에 도착하면 이동 제한
    if (maze.isAtJunction(player.gridPos, player.lastMoveDir)) {
      canMove = false; // 갈림길에서는 이동 금지
      if (onUpdate != null) onUpdate!(); // UI 업데이트 등 호출
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
    if (newGridPos.x < 0 ||
        newGridPos.y < 0 ||
        newGridPos.x >= maze.cols ||
        newGridPos.y >= maze.rows)
      return;

    lastMoveDir = newGridPos - gridPos;
    gridPos = newGridPos.clone();
    position = gridPos * Maze.tileSize;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}

// -------------------- Direction Selection Dialog --------------------
class DirectionSelectionDialog extends StatelessWidget {
  final void Function(Vector2 dir) onSelect;

  const DirectionSelectionDialog({super.key, required this.onSelect});

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
                onPressed: () {
                  onSelect(Vector2(0, -1));
                  Navigator.pop(context);
                },
                child: const Text("↑"),
              ),
              ElevatedButton(
                onPressed: () {
                  onSelect(Vector2(-1, 0));
                  Navigator.pop(context);
                },
                child: const Text("←"),
              ),
              ElevatedButton(
                onPressed: () {
                  onSelect(Vector2(1, 0));
                  Navigator.pop(context);
                },
                child: const Text("→"),
              ),
              ElevatedButton(
                onPressed: () {
                  onSelect(Vector2(0, 1));
                  Navigator.pop(context);
                },
                child: const Text("↓"),
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
  final FocusNode answerFocusNode = FocusNode();

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
      if (mounted &&
          game.maze.isAtJunction(
            game.player.gridPos,
            game.player.lastMoveDir,
          )) {
        if (!showQuestion) {
          setState(() {
            showInfoMessage = true; // 안내문 표시
            infoMessage = "방향을 바꾸고 싶다면, 문제를 풀어야 합니다.";
            showQuestion = true; // 문제 표시
          });
        }
      }
    };

    _loadUserIdAndWords();

    startTimer();
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
        game.gameOver = true;
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
        setState(() {
          showDirectionButtons = false;
          showInfoMessage = false;
        });
        _nextQuestion(); // 다음 문제
      } else {
        // 잘못된 방향 선택 → 다시 문제
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

    // 문제 유형에 따라 정답을 반대로 설정
    final correctAnswer =
        showEnglish
            ? currentWord!["koreanMeaning"]
                .toString()
                .toLowerCase() // 영어 문제 → 한국어 뜻
            : currentWord!["wordEn"].toString().toLowerCase(); // 한국어 문제 → 영어 단어

    if (userAnswer == correctAnswer) {
      // 정답 처리
      setState(() {
        showQuestion = false;
        infoMessage = '정답입니다! 나아갈 방향을 선택하세요.';
        showInfoMessage = true;
        game.canMove = false;
      });

      Future.delayed(Duration.zero, () async {
        Vector2? dir = await showDialog<Vector2>(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => DirectionSelectionDialog(
                onSelect: (d) => Navigator.pop(context, d),
              ),
        );

        if (dir != null) {
          game.movePlayer(dir);

          // 방향 선택 후 일반 통로이면 이동 허용
          if (!game.maze.isAtJunction(
            game.player.gridPos,
            game.player.lastMoveDir,
          )) {
            game.canMove = true;
          }

          _nextQuestion();
          setState(() {
            showQuestion = true;
            showInfoMessage = false;
          });
        }
      });
    } else {
      // 오답 처리
      lives--;
      game.lives = lives;
      if (lives <= 0) game.gameOver = true;

      setState(() {
        infoMessage = '틀렸습니다! 남은 목숨: $lives';
        showInfoMessage = true;
      });
    }

    controller.clear();
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("미로 탈출"),
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
                  // 왼쪽: 남은 시간
                  Text("남은 시간: ${totalTime}s"),
                  const SizedBox(width: 16), // 시간과 단어 사이 간격
                  // 가운데: 단어
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 게임 화면
            Expanded(
              child: Focus(
                autofocus: true,
                focusNode: FocusNode(),
                child: RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: (event) {
                    if (event is RawKeyDownEvent) {
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
                      if (dir != Vector2.zero()) onMove(dir);
                    }
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
              onSubmitted: (_) => checkAnswer(),
            ),
          ],
        ),
      ),
    );
  }
}
