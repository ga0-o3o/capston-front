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

  int timeLeft = 180; // 제한 시간
  int lives = 3;
  bool gameOver = false;

  VoidCallback? onUpdate;
  Random random = Random();

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final screenSize = size;
    int rows = 20; // 미로 크기 크게
    int cols = 20;

    double tileW = screenSize.x / cols;
    double tileH = screenSize.y / rows;
    Maze.tileSize = min(tileW, tileH);

    // MazeGame onLoad 내부
    maze = Maze(rows, cols);
    player = Player(position: maze.startPosition, maze: maze); // <-- maze 전달
    add(maze);
    add(player);
  }

  void movePlayer(Vector2 dir) {
    Vector2 newPos = player.gridPos + dir;
    if (!maze.isWalkable(newPos)) return;

    player.moveTo(newPos);

    // Junction 도착시 콜백
    if (maze.isAtJunction(player.gridPos) && onUpdate != null) {
      onUpdate!();
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

  Maze(this.rows, this.cols) : endPosition = Vector2(cols - 1, rows - 1) {
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

    // endPosition을 통로 중 한 곳으로 설정
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

  bool isAtJunction(Vector2 pos) {
    int count = 0;
    List<Vector2> dirs = [
      Vector2(0, -1),
      Vector2(0, 1),
      Vector2(-1, 0),
      Vector2(1, 0),
    ];
    for (var d in dirs) {
      Vector2 next = pos + d;
      if (isWalkable(next)) count++;
    }
    return count >= 3;
  }

  @override
  void render(Canvas canvas) {
    final paintWall = Paint()..color = Colors.black; // 벽
    final paintPath = Paint()..color = Colors.white; // 이동 가능한 길

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

    gridPos = newGridPos.clone();
    position = gridPos * Maze.tileSize;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.blue; // 플레이어 색상
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}

class DirectionSelectionDialog extends StatelessWidget {
  final void Function(Vector2 dir) onSelect;

  const DirectionSelectionDialog({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("방향 선택"),
      content: const Text("이동할 방향을 선택하세요"),
      actions: [
        // 위
        TextButton(
          onPressed: () {
            onSelect(Vector2(0, -1));
            Navigator.pop(context);
          },
          child: const Text("↑ 위쪽"),
        ),
        // 왼쪽
        TextButton(
          onPressed: () {
            onSelect(Vector2(-1, 0));
            Navigator.pop(context);
          },
          child: const Text("← 왼쪽"),
        ),
        // 오른쪽
        TextButton(
          onPressed: () {
            onSelect(Vector2(1, 0));
            Navigator.pop(context);
          },
          child: const Text("→ 오른쪽"),
        ),
        // 아래
        TextButton(
          onPressed: () {
            onSelect(Vector2(0, 1));
            Navigator.pop(context);
          },
          child: const Text("↓ 아래쪽"),
        ),
      ],
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

  Map<String, dynamic>? currentWord;
  bool showKorean = false;
  bool isLoading = true;

  int totalTime = 180;
  int lives = 3;
  int questionNumber = 0;
  final Random _random = Random();

  String? userId;
  String? token;

  bool showQuestion = false; // 문제를 보여줄지 여부
  bool showDirectionSelection = false; // 방향 선택 버튼 표시 여부

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

  @override
  void initState() {
    super.initState();
    game = MazeGame();
    game.onUpdate = () {
      if (mounted) {
        if (game.maze.isAtJunction(game.player.gridPos)) {
          setState(() {
            showQuestion = true;
          });
        }
      }
    };

    _loadUserIdAndWords();
  }

  void startTimer() {
    timer = async.Timer.periodic(const Duration(seconds: 1), (t) {
      if (totalTime > 0 && !game.gameOver) {
        setState(() {
          totalTime--;
          game.timeLeft = totalTime;
        });
      } else {
        t.cancel();
        game.gameOver = true;
      }
    });
  }

  void _nextQuestion() {
    if (words.isEmpty) return;
    currentWord = words[_random.nextInt(words.length)];
    showKorean = _random.nextBool();
    questionNumber++;
  }

  Future<void> onMove(Vector2 dir) async {
    if (game.gameOver) return;
    game.movePlayer(dir); // dir 전달
  }

  // -------------------- 영어 문제 --------------------
  Future<bool> showQuestionDialog() async {
    if (currentWord == null) return false;
    String word = currentWord?["wordEn"] ?? "";

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

  // -------------------- 방향 선택 버튼 --------------------
  Future<void> _showDirectionButtons(Vector2 currentPos) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        async.Timer? timer;
        return StatefulBuilder(
          builder: (context, setState) {
            timer ??= async.Timer(const Duration(seconds: 3), () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context, null); // 시간 초과
              }
            });

            return AlertDialog(
              title: const Text("방향 선택"),
              content: const Text("3초 안에 이동할 방향을 선택하세요!"),
              actions: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 위쪽
                    TextButton(
                      onPressed: () {
                        timer?.cancel();
                        Navigator.pop(context, true); // 위
                      },
                      child: const Text("↑ 위쪽"),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 왼쪽
                        TextButton(
                          onPressed: () {
                            timer?.cancel();
                            Navigator.pop(context, false); // 왼쪽
                          },
                          child: const Text("← 왼쪽"),
                        ),
                        const SizedBox(width: 20),
                        // 오른쪽
                        TextButton(
                          onPressed: () {
                            timer?.cancel();
                            Navigator.pop(context, null); // 오른쪽
                          },
                          child: const Text("→ 오른쪽"),
                        ),
                      ],
                    ),
                    // 아래쪽
                    TextButton(
                      onPressed: () {
                        timer?.cancel();
                        Navigator.pop(context, false); // 아래
                      },
                      child: const Text("↓ 아래쪽"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      // 시간 초과 → 다시 문제
      bool correct = await showQuestionDialog();
      if (correct) {
        _showDirectionButtons(currentPos);
      }
    } else {
      // 선택한 방향에 따라 좌표 이동
      Vector2 dir;
      switch (result) {
        case true: // 위쪽
          dir = Vector2(0, -1);
          break;
        case false: // 왼쪽/아래 (구분 필요)
          dir = Vector2(-1, 0);
          break;
        default: // 오른쪽
          dir = Vector2(1, 0);
          break;
      }

      Vector2 newPos = currentPos + dir;
      if (game.maze.isWalkable(newPos)) {
        game.movePlayer(newPos);
      }
    }
  }

  void checkAnswer() {
    String answer = controller.text.trim();
    if (currentWord == null) return;

    if (answer.toLowerCase() == (currentWord!["wordEn"] ?? "").toLowerCase()) {
      _nextQuestion();

      // 정답 맞았으면 방향 선택 다이얼로그 보여주기
      setState(() {
        showQuestion = false; // 문제 숨김
      });

      // 다음 프레임에서 다이얼로그 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => DirectionSelectionDialog(
                onSelect: (dir) {
                  game.movePlayer(game.player.gridPos + dir);
                  setState(() {
                    showDirectionSelection = false; // 버튼 숨기기
                  });
                },
              ),
        );
      });
    } else {
      lives--;
      game.lives = lives;
      if (lives <= 0) game.gameOver = true;
      setState(() {});
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
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6E99),
        title: const Text("개인 단어 타워 (솔로 모드)"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // 시간 + 목숨
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("남은 시간: $totalTime s"),
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
              child: Center(
                child:
                    showQuestion
                        ? Text(
                          currentWord != null
                              ? currentWord!["wordEn"] ?? "단어 없음"
                              : "단어 없음",
                          style: const TextStyle(fontSize: 24),
                        )
                        : Container(
                          width: 40,
                          height: 40,
                          color: Colors.white, // 평소 가림막
                        ),
              ),
            ),

            const SizedBox(height: 16),

            // 게임 영역
            Expanded(
              child: Center(
                child: Focus(
                  autofocus: true, // 자동 포커스
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
            ),

            const SizedBox(height: 16),
            // 정답 입력창
            TextField(
              controller: controller,
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
