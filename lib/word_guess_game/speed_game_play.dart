import 'package:flutter/material.dart';
import 'guess_effect.dart';
import 'guess_socket_service.dart';
import 'dart:async';

/// Speed Game 플레이 페이지
/// 서버(Spring Boot) 이벤트 규칙에 100% 맞춤
class SpeedGamePlayPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final String loginId;
  final GuessSocketService socket;

  const SpeedGamePlayPage({
    Key? key,
    required this.roomId,
    required this.userId,
    required this.loginId,
    required this.socket,
  }) : super(key: key);

  @override
  State<SpeedGamePlayPage> createState() => _SpeedGamePlayPageState();
}

class _SpeedGamePlayPageState extends State<SpeedGamePlayPage> {
  // ---------- 단어와 UI ----------
  String _currentWord = '';
  String _currentWordKr = '게임을 준비하고 있습니다...';

  final TextEditingController _answerController = TextEditingController();

  static const int _totalQuestions = 10;
  int _correctCount = 0;

  // ---------- 중복 정답 방지 ----------
  String _lastSolvedWord = '';   // ★ 추가됨

  // ---------- 플레이어 점수 ----------
  Map<String, int> _playerScores = {};
  List<String> _playerOrder = [];

  int get _myScore => _playerScores[widget.loginId] ?? 0;

  // ---------- 게임 상태 ----------
  bool _waitingForWord = true;
  bool _isSubmitting = false;
  bool _gameStarted = false;
  bool _gameOver = false;

  int _remainingSeconds = 60;
  Timer? _gameTimer;

  String _statusMessage = '게임 준비 중...';

  StreamSubscription? _socketSub;

  // ---------- 색상 ----------
  static const Color _bgColor = Color(0xFFF6F0E9);
  static const Color _primary = Color(0xFF213654);
  static const Color _keyCorrect = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    widget.socket.joinRoom(widget.roomId, widget.userId);

    widget.socket.sendGameReady(widget.roomId, userId: widget.userId);

    _socketSub = widget.socket.messages.listen((msg) {
      final event = msg['event'];
      print('📩 [PlayPage] 이벤트: $event');

      switch (event) {
        case 'game_start_speed':
          _onGameStart(msg);
          break;
        case 'word_serve':
          _onWordServe(msg);
          break;
        case 'correct_answer':
          _onCorrect(msg);
          break;
        case 'wrong_answer':
          _onWrong(msg);
          break;
        case 'game_complete':
          _onGameOver(msg);
          break;
      }
    });
  }

  // -------------------------------------------------
  // 게임 시작
  // -------------------------------------------------
  void _onGameStart(Map msg) {
    final data = msg['data'] ?? {};
    final players =
        (data['players'] as List?)?.map((e) => e.toString()).toList() ?? [];

    setState(() {
      _gameStarted = true;
      _playerOrder = players;

      for (var p in players) {
        _playerScores[p] = 0;
      }

      _currentWordKr = '첫 번째 문제를 기다리는 중...';
      _statusMessage = '🎮 게임 시작! 문제 대기 중...';
    });

    _startTimer();
  }

  // -------------------------------------------------
  // 문제 제공
  // -------------------------------------------------
  void _onWordServe(Map msg) {
    final data = msg['data'] ?? {};
    final word = data['word']?.toString() ?? '';

    if (word.isEmpty) return;

    setState(() {
      _currentWord = word;
      _currentWordKr = word;
      _waitingForWord = false;
      _isSubmitting = false;
      _statusMessage = '⚡ 단어를 입력하세요!';
    });

    _answerController.clear();
  }

  // -------------------------------------------------
  // 정답 처리
  // -------------------------------------------------
  void _onCorrect(Map msg) {
    final data = msg['data'] ?? {};
    final solver = data['solver']?.toString() ?? '';
    final word = data['word']?.toString() ?? '';

    // 🔥 중복 방지: 내가 이미 처리한 정답이면 무시
    if (solver == widget.loginId) {
      if (_lastSolvedWord == word) {
        print("⏳ 중복 정답 이벤트 무시됨: $word");
        return;
      }
      _lastSolvedWord = word;
    }

    setState(() {
      _playerScores[solver] = (_playerScores[solver] ?? 0) + 1;
      _waitingForWord = true;
    });

    if (solver == widget.loginId) {
      _showGuessEffect(GuessResultType.hadIt);

      setState(() {
        _correctCount = (_correctCount + 1).clamp(0, _totalQuestions);
        _statusMessage = '🎉 정답! ($_correctCount/$_totalQuestions)';
      });

      if (_correctCount >= _totalQuestions) {
        _gameOver = true;
        _gameTimer?.cancel();

        widget.socket.sendGameOver(
          roomId: widget.roomId,
          loginId: widget.loginId,
          score: _correctCount,
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showGameOverDialog(widget.loginId, _correctCount);
          }
        });
      }
    } else {
      setState(() {
        _statusMessage = '💨 $solver 님이 먼저 맞췄습니다!';
      });
    }

    _answerController.clear();
    _isSubmitting = false;
  }

  // -------------------------------------------------
  // 오답 처리
  // -------------------------------------------------
  void _onWrong(Map msg) {
    setState(() {
      _statusMessage = '❌ 오답입니다. 다시 시도하세요!';
      _isSubmitting = false;
    });

    _answerController.clear();
  }

  void _onGameOver(Map msg) {
    if (_gameOver) return;
    _gameOver = true;

    _gameTimer?.cancel();

    final data = msg['data'] ?? {};
    final winner = data['winner']?.toString() ?? '';
    final score = data['score'] ?? 0;

    _showGameOverDialog(winner, score);
  }

  // ---------- 타이머 ----------
  void _startTimer() {
    _gameTimer?.cancel();

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          widget.socket.sendGameOver(
            roomId: widget.roomId,
            loginId: widget.loginId,
            score: _myScore,
          );
        }
      });
    });
  }

  // -------------------------------------------------
  // 정답 제출
  // -------------------------------------------------
  void _submitAnswer() {
    if (_waitingForWord || _isSubmitting || _gameOver) return;

    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _statusMessage = '답을 입력하세요!');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = '채점 중...';
    });

    widget.socket.sendAnswer(
      roomId: widget.roomId,
      loginId: widget.loginId,
      word: _currentWord,
      wordKr: answer,
    );
  }

  // -------------------------------------------------
  // 게임 종료 Dialog
  // -------------------------------------------------
  void _showGameOverDialog(String winner, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('🎉 게임 종료'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                winner == widget.loginId
                    ? '🏆 당신이 승리했습니다!\n점수: $score점'
                    : '😢 $winner 님이 승리했습니다.\n점수: $score점',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                '최종 순위',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._buildFinalRanking(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildFinalRanking() {
    final sorted = _playerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${e.key} - ${e.value}점'),
            ))
        .toList();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _socketSub?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  // 정답 효과
  void _showGuessEffect(GuessResultType type) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, a, __) => FadeTransition(
          opacity: a,
          child: GuessEffectPage(resultType: type),
        ),
      ),
    );
  }

  // ========================================
  // UI BUILD (디자인 절대 변경 금지)
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildComputer(),
                    const SizedBox(height: 32),
                    _buildAnswerArea(),
                  ],
                ),
              ),
            ),
            _buildFooterMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, color: _primary),
              const SizedBox(width: 8),
              const Text(
                'Fast Word Guess',
                style: TextStyle(
                  color: _primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_gameStarted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remainingSeconds > 10 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⏱ $_remainingSeconds초',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),

          if (_playerOrder.isNotEmpty && _gameStarted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: _playerOrder.map((player) {
                  final score = _playerScores[player] ?? 0;
                  final isMe = (player == widget.loginId);

                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMe ? _primary : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isMe ? '나' : player,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$score점',
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterMessage() {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFD7C0A0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      alignment: Alignment.center,
      child: Text(
        _statusMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF3E2A1C),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ======================================================
  // 🔥 Skip 버튼이 포함된 문제 박스 UI
  // ======================================================
  Widget _buildComputer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 195,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(36),
              ),
            ),

            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _primary, width: 18),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      _currentWordKr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _waitingForWord ? 20 : 32,
                        fontWeight: _waitingForWord
                            ? FontWeight.w500
                            : FontWeight.bold,
                        color: _waitingForWord
                            ? Colors.grey[700]
                            : const Color(0xFF3E2A1C),
                      ),
                    ),
                  ),

                  // 🔥 Skip 버튼 추가
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: ElevatedButton(
                      onPressed: () {
                        // 기능은 나중에 추가 예정
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Skip",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_totalQuestions, (i) {
              final isFilled = i < _correctCount;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isFilled ? _keyCorrect : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isFilled
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              );
            }),
          ),
        )
      ],
    );
  }

  Widget _buildAnswerArea() {
    return Column(
      children: [
        TextField(
          controller: _answerController,
          enabled: !_waitingForWord && !_isSubmitting && !_gameOver,
          onSubmitted: (_) => _submitAnswer(),
          decoration: InputDecoration(
            hintText:
                _waitingForWord ? '다음 문제를 준비 중...' : '영어 단어를 입력하세요',
            filled: true,
            fillColor: _waitingForWord ? Colors.grey[200] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed:
                (_waitingForWord || _isSubmitting || _gameOver) ? null : _submitAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isSubmitting
                  ? '제출 중...'
                  : _waitingForWord
                      ? '대기 중...'
                      : '확인',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
