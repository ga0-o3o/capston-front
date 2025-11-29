// guess_game.dart - Speed Game (턴 없는 실시간 경쟁)
import 'package:flutter/material.dart';
import 'guess_effect.dart';
import 'guess_socket_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class GuessGamePage extends StatefulWidget {
  final String? roomId;
  final String? userId;
  final GuessSocketService? socket;

  const GuessGamePage({
    Key? key,
    this.roomId,
    this.userId,
    this.socket,
  }) : super(key: key);

  @override
  State<GuessGamePage> createState() => _GuessGamePageState();
}

class _GuessGamePageState extends State<GuessGamePage> {
  // ✅ 공통 단어 (모든 플레이어가 동일하게 봄)
  String _currentWord = ''; // 영어 단어 (정답)
  String _currentWordKr = '매칭 대기 중...'; // 한글 뜻 (화면에 표시)

  // 정답 입력용 컨트롤러
  final TextEditingController _answerController = TextEditingController();

  // ✅ 플레이어 점수 맵 (loginId -> score)
  Map<String, int> _playerScores = {};
  List<String> _playerOrder = []; // 플레이어 순서

  // 내 점수
  int get _myScore => _playerScores[_loginId] ?? 0;

  String _statusMessage = '매칭 중...';

  int _correctCount = 0;
  int _currentWordLength = 10; // ✅ 동적으로 변경되는 단어 길이

  static const Color _bgColor = Color(0xFFF6F0E9);
  static const Color _primary = Color(0xFF213654);
  static const Color _keyDefault = Colors.white;
  static const Color _keyCorrect = Color(0xFF4CAF50);

  // WebSocket 관련
  String _loginId = '';
  StreamSubscription? _socketSubscription;
  bool _gameStarted = false;
  bool _gameOver = false;

  // 타이머
  int _remainingSeconds = 60;
  Timer? _gameTimer;

  // ✅ 정답 제출 중 플래그 (중복 제출 방지)
  bool _isSubmitting = false;

  // ✅ 단어 수신 대기 플래그
  bool _waitingForWord = true;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    // 로그인 ID 가져오기
    final prefs = await SharedPreferences.getInstance();
    _loginId = prefs.getString('user_id') ?? '';

    if (widget.socket != null && widget.roomId != null) {
      // WebSocket 모드: 방 참가 요청
      final safeUserId =
          widget.userId ?? (_loginId.isNotEmpty ? _loginId : 'guest');

      print('🎮 [Speed] 게임 시작: roomId=${widget.roomId}, userId=$safeUserId');
      widget.socket!.joinRoom(widget.roomId!, safeUserId);

      // 이벤트 리스너 등록
      _socketSubscription = widget.socket!.messages.listen((msg) {
        if (!mounted) return;
        final event = msg['event'];

        print('📩 [Speed] 이벤트 수신: $event');

        // ✅ 이벤트 처리
        if (event == 'all_words_speed') {
          // ✅ 전체 단어 리스트 수신
          print('✅ [Speed] 단어 리스트 수신 완료!');

          if (!mounted) return;
          setState(() {
            _currentWordKr = '게임이 곧 시작됩니다!';
            _statusMessage = '다른 플레이어를 기다리는 중...';
          });

          // 보드 준비 완료 전송
          widget.socket!.sendGameReady(widget.roomId!, userId: widget.userId);
        } else if (event == 'game_start_speed') {
          // ✅ 게임 시작
          final data = msg['data'] as Map<String, dynamic>?;
          final players =
              (data?['players'] as List?)?.map((e) => e.toString()).toList() ??
                  [];
          print('🎮 [Speed] 게임 시작! 플레이어: $players');

          if (!mounted) return;
          setState(() {
            _gameStarted = true;
            _playerOrder = players;
            // 초기 점수 설정
            for (var player in players) {
              _playerScores[player] = 0;
            }
            _currentWordKr = '첫 번째 문제를 준비하고 있습니다...';
            _statusMessage = '🎮 게임 시작! 단어를 기다리는 중...';
            _waitingForWord = true;
          });

          // 60초 타이머 시작
          _startTimer();
        } else if (event == 'word_ready_speed') {
          // ✅✅✅ 핵심! 서버에서 보내는 word_ready_speed 이벤트 처리
          print('═══════════════════════════════════════════════════════');
          print('📩 [Speed] word_ready_speed 이벤트 수신!');

          final word = msg['word']?.toString() ?? '';
          print('📝 [Speed] 받은 단어: "$word"');

          if (word.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _currentWord = word;
              _currentWordKr = word; // 화면에 표시할 단어
              _currentWordLength = word.length; // ✅ 단어 길이에 맞춰 박스 개수 설정
              _statusMessage = '⚡ 빠르게 단어를 입력하세요!';
              _isSubmitting = false;
              _waitingForWord = false;
            });
            print('✅ [Speed] UI 업데이트 완료! 단어: $word (길이: ${word.length})');

            // 입력창 초기화
            _answerController.clear();
          } else {
            print('⚠️ [Speed] 단어가 비어있습니다!');
          }
          print('═══════════════════════════════════════════════════════');
        } else if (event == 'speed_new_word') {
          // ✅ 서버에서 data 형식으로 보낼 경우 대비
          print('📩 [Speed] speed_new_word 이벤트 수신!');

          final data = msg['data'] as Map<String, dynamic>?;
          final word = data?['word']?.toString() ?? '';
          final wordKr = data?['wordKr']?.toString() ?? '';

          if (word.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _currentWord = word;
              _currentWordKr = wordKr.isNotEmpty ? wordKr : word;
              _currentWordLength = word.length;
              _statusMessage = '⚡ 빠르게 단어를 입력하세요!';
              _isSubmitting = false;
              _waitingForWord = false;
            });
            print('✅ [Speed] UI 업데이트 완료! 단어: $word (길이: ${word.length})');

            _answerController.clear();
          }
        } else if (event == 'speed_answer_result') {
          // ✅ 누군가 정답을 맞춤
          final data = msg['data'] as Map<String, dynamic>?;
          final loginId = data?['loginId']?.toString() ?? '';
          final word = data?['word']?.toString() ?? '';
          final answer = data?['answer']?.toString() ?? '';

          // ✅ Boolean 변환 처리 (문자열 "true"/"false"도 처리)
          bool isCorrect = false;
          final isCorrectRaw = data?['isCorrect'];
          if (isCorrectRaw is bool) {
            isCorrect = isCorrectRaw;
          } else if (isCorrectRaw is String) {
            isCorrect = isCorrectRaw.toLowerCase() == 'true';
          }

          if (isCorrect) {
            // ✅ 정답! 점수 증가
            if (!mounted) return;
            setState(() {
              _playerScores[loginId] = (_playerScores[loginId] ?? 0) + 1;

              if (loginId == _loginId) {
                // ✅ 내가 맞춤 → 내 칸만 채워짐
                _correctCount =
                    (_correctCount + 1).clamp(0, _currentWordLength);
                _statusMessage = '🎉 정답! +1점 (${_playerScores[loginId]}점)';
                _showGuessEffect(GuessResultType.hadIt);
                print(
                    '🎉 [Speed] 내가 정답을 맞혔습니다! 현재 칸: $_correctCount/$_currentWordLength');

                // 다음 문제 대기 상태
                _waitingForWord = true;
                _currentWordKr = '다음 문제를 준비하고 있습니다...';
              } else {
                // ✅ 다른 플레이어가 맞춤 → 내 칸은 안 채워짐
                _statusMessage = '💨 $loginId님이 먼저 맞혔습니다!';
                print('😢 [Speed] $loginId님이 먼저 맞췄습니다. (내 칸은 안 채워짐)');

                // 다음 문제 대기 상태
                _waitingForWord = true;
                _currentWordKr = '다음 문제를 준비하고 있습니다...';
              }
            });

            // 입력창 비우기
            _answerController.clear();
            _isSubmitting = false;
          } else {
            // ❌ 오답
            if (loginId == _loginId) {
              // 내가 틀림
              if (!mounted) return;
              setState(() {
                _statusMessage = '❌ 오답! 다시 도전하세요!';
              });
              _isSubmitting = false;
              print('❌ [Speed] 내가 틀렸습니다: "$answer"');

              // 입력창 내용만 지우고 다시 시도
              _answerController.clear();
            }
          }

          print('📢 [Speed] $loginId가 "$answer" 제출 (정답 여부: $isCorrect)');
        } else if (event == 'speed_game_over') {
          // 게임 종료
          final data = msg['data'] as Map<String, dynamic>?;
          final winner = data?['winner']?.toString() ?? '';
          final winnerScore = data?['score'] as int? ?? 0;

          _handleGameOver(winner, winnerScore);
        }
      });
    } else {
      // ✅ 로컬 테스트 모드
      setState(() {
        _currentWord = 'apple'; // 정답
        _currentWordKr = 'apple'; // 화면에 표시될 단어
        _currentWordLength = 5; // 단어 길이
        _statusMessage = '⚡ 단어를 빠르게 입력하세요!';
        _playerScores[_loginId] = 0;
        _playerOrder = [_loginId];
        _gameStarted = true;
        _waitingForWord = false;
      });
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          // 시간 종료
          timer.cancel();
          _endGame();
        }
      });
    });
  }

  void _endGame() {
    if (_gameOver) return;
    _gameOver = true;

    // 승리 선언 (현재 점수 전송)
    if (widget.socket != null && widget.roomId != null && _loginId.isNotEmpty) {
      widget.socket!.sendGameOver(
        roomId: widget.roomId!,
        loginId: _loginId,
        score: _myScore,
      );
    }

    // 로컬에서는 바로 결과 표시
    if (widget.socket == null) {
      _showGameOverDialog('당신', _myScore);
    }
  }

  void _handleGameOver(String winner, int winnerScore) {
    if (!mounted) return;
    _gameTimer?.cancel();
    _gameOver = true;

    _showGameOverDialog(winner, winnerScore);
  }

  void _showGameOverDialog(String winner, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 게임 종료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              winner == _loginId || winner == '당신'
                  ? '🏆 축하합니다! 당신이 승리했습니다!\n점수: $score점'
                  : '😢 $winner님이 승리했습니다!\n점수: $score점\n내 점수: $_myScore점',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '최종 순위:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._buildFinalRanking(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // 게임 페이지 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFinalRanking() {
    final sortedPlayers = _playerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPlayers.asMap().entries.map((entry) {
      final rank = entry.key + 1;
      final player = entry.value;
      final isMe = player.key == _loginId;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$rank위: ${player.key} - ${player.value}점',
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            color: isMe ? Colors.blue : Colors.black,
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _socketSubscription?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _showGuessEffect(GuessResultType type) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: GuessEffectPage(
              resultType: type,
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  void _submitAnswer() {
    if (_gameOver || _isSubmitting || _waitingForWord) return;

    final answer = _answerController.text.trim();

    if (answer.isEmpty) {
      setState(() {
        _statusMessage = '단어를 입력해 주세요!';
      });
      return;
    }

    // ✅ 제출 중 플래그 설정 (중복 제출 방지)
    _isSubmitting = true;

    // WebSocket 모드: 서버에 답안 제출
    if (widget.socket != null && widget.roomId != null && _loginId.isNotEmpty) {
      widget.socket!.sendAnswer(
        roomId: widget.roomId!,
        loginId: _loginId,
        word: _currentWord,
        wordKr: answer,
      );

      setState(() {
        _statusMessage = '제출 중...';
      });
    } else {
      // 로컬 테스트: 즉시 정답 확인
      final bool isCorrect = answer.toLowerCase() == _currentWord.toLowerCase();

      setState(() {
        if (isCorrect) {
          _playerScores[_loginId] = (_playerScores[_loginId] ?? 0) + 1;
          _statusMessage = '🎉 정답! +1점';
          _correctCount = (_correctCount + 1).clamp(0, _currentWordLength);

          // 로컬 모드에서는 즉시 다음 문제 (여기서는 같은 문제 반복)
          _currentWordKr = 'apple';
        } else {
          _statusMessage = '❌ 오답! 다시 도전하세요!';
        }
        _isSubmitting = false;
      });

      _answerController.clear();

      if (isCorrect) {
        _showGuessEffect(GuessResultType.hadIt);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 상단 상태 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flash_on, color: _primary, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        '단어 빨리 맞추기',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // 타이머
                      if (_gameStarted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _remainingSeconds > 10
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '⏱️ $_remainingSeconds초',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // ✅ 플레이어 점수 표시 (Wrap으로 overflow 방지)
                  if (_gameStarted && _playerOrder.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: _playerOrder.map((player) {
                          final score = _playerScores[player] ?? 0;
                          final isMe = player == _loginId;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? _primary : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isMe ? '나' : player,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$score점',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
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
            ),

            const SizedBox(height: 24),

            // 컴퓨터 영역
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildComputer(),
                    const SizedBox(height: 32),
                    _buildAnswerArea(),
                  ],
                ),
              ),
            ),

            // 하단 정보창
            Container(
              height: 80,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFD7C0A0),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3E2A1C),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.15),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF5F57),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFEBB2E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF28C840),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.wifi, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        const Icon(Icons.battery_full,
                            color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.8, end: 1.0)
                                    .animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _currentWordKr, // ✅ 단어 표시 (서버에서 받은 text)
                            key: ValueKey<String>(_currentWordKr),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _waitingForWord ? 18 : 32,
                              fontWeight: _waitingForWord
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: _waitingForWord
                                  ? Colors.grey[600]
                                  : const Color(0xFF3E2A1C),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Transform.translate(
          offset: const Offset(0, -8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 28,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 150,
                height: 18,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ✅ RenderFlex overflow 완전 제거: Wrap 사용 + 단어 길이에 맞춰 동적 생성
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_currentWordLength, (index) {
              final isFilled = index < _correctCount;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isFilled ? _keyCorrect : _keyDefault.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        isFilled ? _keyCorrect : _keyDefault.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isFilled
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
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
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitAnswer(),
          enabled: !_gameOver && !_isSubmitting && !_waitingForWord,
          autofocus: false,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: _waitingForWord ? '다음 문제 준비 중...' : '영어 단어를 입력하세요',
            hintStyle: TextStyle(
              color: _waitingForWord ? Colors.grey[400] : Colors.grey[600],
            ),
            filled: true,
            fillColor: _waitingForWord ? Colors.grey[100] : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            onPressed: (_gameOver || _isSubmitting || _waitingForWord)
                ? null
                : _submitAnswer,
            child: Text(
              _isSubmitting
                  ? '제출 중...'
                  : _waitingForWord
                      ? '대기 중...'
                      : '확인',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
