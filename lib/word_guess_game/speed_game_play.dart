// (1/3 영역 시작)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'guess_effect.dart';
import 'guess_socket_service.dart';
import '../pages/game_menu_page.dart';
import '../pages/mainMenuPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guess_match_page.dart';

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
  String _currentWord = '';
  String _currentWordKr = '게임을 준비하고 있습니다...';

  final TextEditingController _answerController = TextEditingController();

  static const int _totalQuestions = 10;
  int _correctCount = 0;

  String _lastSolvedWord = '';

  Map<String, int> _playerScores = {};
  List<String> _playerOrder = [];

  int get _myScore => _playerScores[widget.loginId] ?? 0;

  bool _waitingForWord = true;
  bool _isSubmitting = false;
  bool _gameStarted = false;
  bool _gameOver = false;
  bool _skipUsed = false;

  int _remainingSeconds = 60;
  Timer? _gameTimer;

  String _statusMessage = '게임 준비 중...';

  StreamSubscription? _socketSub;

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
        case 'game_end_speed':
          _onGameEndSpeed(msg);
          break;
        case 'game_result':
          _onGameResult(msg);
          break;
        case 'game_complete':
        case 'game_over':
        case 'speed_game_winner':
          _onGameOver(msg);
          break;
      }
    });
  }

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

  void _onWordServe(Map msg) {
    final data = msg['data'] ?? {};
    final word = data['word']?.toString() ?? '';
    final lastSolver = data['lastSolver'];
    final message = data['message']?.toString() ?? '';

    if (word.isEmpty) return;

    if (message != 'START' && lastSolver == null) {
      setState(() {
        _statusMessage = '❌ 아무도 못맞춤 - 다음 문제!';
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _statusMessage = '⚡ 단어를 입력하세요!');
        }
      });
    }

    setState(() {
      _currentWord = word;
      _currentWordKr = word;
      _waitingForWord = false;
      _isSubmitting = false;
      _skipUsed = false;

      if (message == 'START') {
        _statusMessage = '⚡ 게임 시작! 단어를 입력하세요!';
      }
    });

    _answerController.clear();
  }

  void _onCorrect(Map msg) {
    final data = msg['data'] ?? {};
    final solver = data['solver']?.toString() ?? '';
    final word = data['word']?.toString() ?? '';

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
          if (mounted) _showGameEndDialog(widget.loginId, _correctCount);
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

  void _onWrong(Map msg) {
    setState(() {
      _statusMessage = '❌ 오답입니다. 다시 시도하세요!';
      _isSubmitting = false;
    });

    _answerController.clear();
  }

// (1/3 영역 끝)
// (2/3 영역 시작)

  void _onGameEndSpeed(Map msg) {
    if (_gameOver) return;
    _gameOver = true;

    _gameTimer?.cancel();

    final data = msg['data'] ?? {};
    final winner = data['winner']?.toString() ?? '';
    final finalScores = data['finalScores'] ?? {};

    if (finalScores is Map) {
      setState(() {
        _playerScores = finalScores.map(
          (key, value) => MapEntry(key.toString(), (value ?? 0) as int),
        );
      });
    }

    final int winnerScore = _playerScores[winner] ?? 0;

    _showGameEndDialog(winner, winnerScore);
  }

  void _onGameOver(Map msg) {
    if (_gameOver) return;
    _gameOver = true;

    _gameTimer?.cancel();

    final data = msg['data'] ?? {};
    final winner = data['winner']?.toString() ?? '';
    final score = data['score'] ?? 0;

    if (data['scores'] != null && data['scores'] is Map) {
      final scores = data['scores'] as Map;
      setState(() {
        _playerScores = scores.map(
          (key, value) => MapEntry(key.toString(), (value ?? 0) as int),
        );
      });
    }

    _showGameOverDialog(winner, score);
  }

  void _onGameResult(Map msg) {
    if (_gameOver) return;
    _gameOver = true;

    _gameTimer?.cancel();

    final data = msg['data'] ?? {};
    final winner = data['winner']?.toString() ?? '';

    final bool iWin = winner == widget.loginId;

    _showGameResultDialog(winner, iWin);
  }

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
  // You Win / You Lose — 10문제 먼저 맞춘 경우
  // -------------------------------------------------
  void _showGameEndDialog(String winner, int winnerScore) {
    if (!mounted) return;

    final bool iWin = winner == widget.loginId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            iWin ? '🎉 You Win!'
                 : '😢 You Lose!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: iWin ? Colors.green : Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                iWin
                    ? '축하합니다! 10문제를 먼저 맞추셨습니다!'
                    : '$winner 님이 10문제를 먼저 맞추셨습니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '승자 점수: $winnerScore점',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                '최종 순위',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._buildFinalRanking(),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();

                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const GameMenuPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 14),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  // -------------------------------------------------
  // 기타 종료 — 타이머 종료 등
  // -------------------------------------------------
  void _showGameOverDialog(String winner, int score) {
    if (!mounted) return;

    final bool iWin = winner == widget.loginId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            iWin ? '🎉 You Win!' : '😢 You Lose!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iWin ? Colors.green : Colors.red,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                iWin
                    ? '축하합니다! 당신이 승리했습니다!'
                    : '$winner 님이 승리했습니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '점수: $score점',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                '최종 순위',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._buildFinalRanking(),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();

                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const GameMenuPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 14),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameResultDialog(String winner, bool iWin) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            iWin ? '🎉 You Win!' : '😢 You Lose!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: iWin ? Colors.green : Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                iWin
                    ? '축하합니다! 당신이 승리했습니다!'
                    : '$winner 님이 승리했습니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                '최종 순위',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._buildFinalRanking(),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();

                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const GameMenuPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 14),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

// (2/3 영역 끝)
// (3/3 영역 시작)

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

  Widget _buildComputer() {
    return Column(
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
                        fontWeight:
                            _waitingForWord ? FontWeight.w500 : FontWeight.bold,
                        color: _waitingForWord
                            ? Colors.grey[700]
                            : const Color(0xFF3E2A1C),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: ElevatedButton(
                      onPressed: _skipUsed
                          ? null
                          : () {
                              setState(() => _skipUsed = true);
                              widget.socket.sendAnswer(
                                roomId: widget.roomId,
                                loginId: widget.loginId,
                                word: "{skip}",
                                wordKr: "{master_key}",
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _skipUsed
                            ? _primary.withOpacity(0.3)
                            : _primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          color: _skipUsed
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
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
        ),
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
            hintText: _waitingForWord ? '다음 문제를 준비 중...' : '영어 단어를 입력하세요',
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

// (3/3 영역 끝)
