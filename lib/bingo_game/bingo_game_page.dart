import 'package:flutter/material.dart';
import 'bingo_socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bingo_quiz.dart';
import 'dart:math';
import 'dart:async';
import 'bingo_effect.dart';

String _normId(Object? v) => (v ?? '').toString().trim().toLowerCase();
String _normWord(Object? v) => (v ?? '').toString().trim().toLowerCase();

int _hashString(String s) {
  var h = 0x811C9DC5; // FNV-like seed
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

List<T> _deterministicShuffle<T>(List<T> src, String seed) {
  final list = List<T>.from(src);
  final rnd = Random(_hashString(seed));
  for (int i = list.length - 1; i > 0; i--) {
    final j = rnd.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list;
}

class BingoGamePage extends StatefulWidget {
  final String roomId;
  final String userId;
  final BingoSocketService socket;

  const BingoGamePage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.socket,
  });

  @override
  State<BingoGamePage> createState() => _BingoGamePageState();
}

// 보드/풀 단어 이동용
class DragWord {
  final String word;
  final int? srcRow;
  final int? srcCol;

  const DragWord(this.word, {this.srcRow, this.srcCol});

  bool get fromBoard => srcRow != null && srcCol != null;
}

class _TurnBadge extends StatelessWidget {
  final bool isMine;
  final String? orderText;
  const _TurnBadge({required this.isMine, this.orderText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF4E6E99) : Colors.grey.shade500,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isMine ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded,
              size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            isMine ? '나의 차례' : '상대 차례',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (orderText != null) ...[
            const SizedBox(width: 8),
            Text(
              orderText!,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 단계 구분
enum _Phase { setup, playing, ended }

class _BingoGamePageState extends State<BingoGamePage> {
  List<String> availableWords = [];
  List<List<String?>> bingoBoard =
      List.generate(5, (_) => List.filled(5, null));

  // 상태 분리: 내가 맞춘(X) / 남이 맞춘(하이라이트)
  // ※ 항상 _normWord()로 정규화된 값만 저장한다.
  final Set<String> crossedMine = {};
  final Set<String> crossedOthers = {};

  // 단계/준비
  _Phase _phase = _Phase.setup;
  bool _boardFilled = false;
  bool _iAmReady = false;

  // 준비 인원
  int _readyCount = 0;
  int _totalPlayers = 0;

  // 턴/유저
  List<String> _roomUsers = [];
  List<String> _order = [];
  bool _orderFixed = false;
  String? _activeUserId;
  int _turnIndex = 0;

  // 내 빙고 수/승리 표시
  int _myBingoCount = 0;
  bool _winAnnounced = false;

  // 안내 오버레이 상태
  bool _showGuide = true; // 처음엔 안내문 표시
  bool _wordsLoaded = false; // all_words 받으면 true

  // 하이라이트 응답 타이머 (정규화된 word 키로 관리)
  final Map<String, Timer> _highlightTimers = {};
  final Set<String> _highlightResponded = {}; // 정규화된 word 기준

  // 🎯 중복 단어 관리 (정규화된 word 키로 관리)
  final Map<String, bool> _duplicateWordFirstChance = {}; // 첫 기회 여부
  final Set<String> _duplicateWordAttempted = {}; // 이미 시도한 중복 단어
  final Set<String> _myAttemptedWords = {}; // 🎯 내가 시도한 모든 단어 (중복 표시 방지용)

  // 이펙트 표시 상태
  bool _showBingoEffect = false;
  int _effectCount = 0; // 1/2/3
  int _lastShownEffect = 0; // 같은 빙고 수 재생 방지

  // 🔹 퀴즈 정답/실패 이펙트 상태
  bool _showAnswerEffect = false;
  bool _lastAnswerCorrect = false;

  // 🔹 정답 이펙트 후 재생할 빙고 이펙트 예약용
  int? _queuedBingoCount;

  // 🔹 Effect 중복 방지용
  String? _lastEffectWord;
  int _lastEffectTime = 0;

  // 🎯 현재 검사 중인 단어 (서버 응답 대기 중)
  String? _wordUnderReview;

  // ⏱️ 턴 타이머 관련
  int? _turnStartTime; // 서버에서 받은 턴 시작 시각 (밀리초)
  int _turnDuration = 20; // 턴 제한 시간 (초)
  Timer? _turnTimer; // 1초마다 UI 업데이트
  int _remainingSeconds = 0; // 남은 시간 (초)

// 결과 다이얼로그 1회만 뜨도록 가드
  bool _dialogShown = false;
// 내가 승리 브로드캐스트를 이미 보냈는지 가드
  bool _winEventSent = false;

  bool get _isMyTurn => _normId(widget.userId) == (_activeUserId ?? '');

  // === 보조 ===
  bool _boardHasWord(String w) {
    final nw = _normWord(w);
    for (final row in bingoBoard) {
      for (final cell in row) {
        if (_normWord(cell) == nw) return true;
      }
    }
    return false;
  }

  int _recalcMyBingos() {
    int count = 0;

    bool lineOk(List<List<int>> cells) {
      for (final rc in cells) {
        final r = rc[0], c = rc[1];
        final w = bingoBoard[r][c];
        if (w == null || !crossedMine.contains(_normWord(w))) return false;
      }
      return true;
    }

    // 5행
    for (int r = 0; r < 5; r++) {
      final cells = List.generate(5, (c) => [r, c]);
      if (lineOk(cells)) count++;
    }
    // 5열
    for (int c = 0; c < 5; c++) {
      final cells = List.generate(5, (r) => [r, c]);
      if (lineOk(cells)) count++;
    }
    // 대각선 2개
    final diag1 = List.generate(5, (i) => [i, i]);
    final diag2 = List.generate(5, (i) => [i, 4 - i]);
    if (lineOk(diag1)) count++;
    if (lineOk(diag2)) count++;

    return count;
  }

  void _checkWinAfterMark({String? lastWord}) {
    final newCount = _recalcMyBingos();
    if (newCount != _myBingoCount) {
      setState(() => _myBingoCount = newCount);
      _tryShowBingoEffect(newCount);
    }

    if (!_winAnnounced && newCount >= 3) {
      _winAnnounced = true;

      // 서버에 승리 알림 (이벤트명은 백엔드와 합의)
      widget.socket.sendUserWordEvent(
        roomId: widget.roomId,
        loginId: widget.userId,
        event: 'bingo_win',
        word: lastWord ?? '',
        wordKr: '3-bingo',
        wasHighlighted: false,
      );

      setState(() {
        _phase = _Phase.ended;
      });
    }
  }

  void _tryShowBingoEffect(int newCount) {
    if (newCount <= 0) return;
    if (newCount == _lastShownEffect) return; // 같은 수 재생 방지

    // 🔸 정답/오답 이펙트가 재생 중이면, 일단 예약만 하고 나중에 실행
    if (_showAnswerEffect) {
      _queuedBingoCount = newCount;
      return;
    }

    // 바로 빙고 이펙트 재생
    setState(() {
      _effectCount = newCount.clamp(1, 3);
      _showBingoEffect = true;
      _lastShownEffect = newCount;
    });
  }

  void _startHighlightDeadline(String word) {
    final nw = _normWord(word);
    print('⏰ _startHighlightDeadline 호출: word=$word (nw=$nw)');
    print(
        '   _highlightResponded.contains($nw) = ${_highlightResponded.contains(nw)}');

    if (_highlightResponded.contains(nw)) {
      print('   ⏭️ 이미 응답했으므로 타이머 시작 안 함');
      return;
    }

    _highlightTimers[nw]?.cancel();
    print('   ⏰ 타이머 시작 (10초)');

    _highlightTimers[nw] = Timer(const Duration(seconds: 10), () {
      if (!_highlightResponded.contains(nw)) {
        print('   ⏱️ 타이머 만료! 미응답 처리');
        _highlightResponded.add(nw);
        widget.socket.sendUserWordEvent(
          roomId: widget.roomId,
          loginId: widget.userId,
          event: 'word_hilight',
          word: word,
          wordKr: " ", // 미응답자: 공백 전송
          wasHighlighted: true,
        );
      }
      _highlightTimers.remove(nw);
    });
  }

  void _cancelHighlightDeadline(String word) {
    final nw = _normWord(word);
    _highlightTimers[nw]?.cancel();
    _highlightTimers.remove(nw);
  }

  void _showAnswerResultEffect(bool correct, String word) {
    if (!mounted) return; // ✅ mounted 체크 추가

    final nw = _normWord(word);
    final now = DateTime.now().millisecondsSinceEpoch;

    // 🔹 중복 방지: 같은 단어에 대해 1초 이내 중복 effect 방지
    if (_lastEffectWord == nw && (now - _lastEffectTime) < 1000) {
      print(
          '   ⏭️ Effect 중복 방지: $_lastEffectWord (${now - _lastEffectTime}ms 전에 표시됨)');
      return;
    }

    print('   🎬 Effect 표시: correct=$correct, word=$nw');
    _lastEffectWord = nw;
    _lastEffectTime = now;

    setState(() {
      _lastAnswerCorrect = correct;
      _showAnswerEffect = true;
    });
  }

  late final StreamSubscription<Map<String, dynamic>> _sockSub;

  @override
  void initState() {
    super.initState();
    _sockSub = widget.socket.messages.listen((msg) {
      if (!mounted) return;
      _handleSocketMessage(msg); // 기존 핸들러 재사용
    });
    widget.socket.joinRoom(widget.roomId, widget.userId);
  }

  @override
  void dispose() {
    _sockSub.cancel();
    // 하이라이트 타이머도 정리
    for (final t in _highlightTimers.values) {
      t.cancel();
    }
    _highlightTimers.clear();
    // ⏱️ 턴 타이머 정리
    _turnTimer?.cancel();
    super.dispose();
  }

  // ⏱️ 턴 타이머 시작 (서버 시간 기준)
  void _startTurnTimer(int serverStartTime, int duration) {
    _turnTimer?.cancel();
    _turnStartTime = serverStartTime;
    _turnDuration = duration;

    // 즉시 남은 시간 계산
    _updateRemainingTime();

    // 1초마다 UI 업데이트
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  // ⏱️ 남은 시간 계산 및 UI 업데이트
  void _updateRemainingTime() {
    if (_turnStartTime == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - _turnStartTime!) / 1000; // 경과 시간 (초)
    final remaining = (_turnDuration - elapsed).ceil();

    setState(() {
      _remainingSeconds = remaining > 0 ? remaining : 0;
    });

    // 시간 종료 시 타이머 중지
    if (_remainingSeconds <= 0) {
      _turnTimer?.cancel();
    }
  }

  // ⏱️ 턴 타이머 중지
  void _stopTurnTimer() {
    _turnTimer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _turnStartTime = null;
    });
  }

  void _maybeFixOrderAndStart() {
    if (_orderFixed) return;
    if (_totalPlayers <= 0) return;
    if (_readyCount < _totalPlayers) return;
    if (_phase != _Phase.setup) return;
    if (_roomUsers.isEmpty) return;

    final normalized = _roomUsers.map(_normId).toList()..sort();
    final order = _deterministicShuffle<String>(normalized, widget.roomId);

    setState(() {
      _order = order;
      _orderFixed = true;
      _activeUserId = _order.first;
      _turnIndex = 0;
      _phase = _Phase.playing;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎲 순서 확정: ${_order.join(" → ")}')),
    );
  }

  void _advanceTurnLocal() {
    if (_order.isEmpty) return;
    setState(() {
      _turnIndex = (_turnIndex + 1) % _order.length;
      _activeUserId = _order[_turnIndex];
    });
  }

  void _handleSocketMessage(Map<String, dynamic> msg) {
    final event = msg['event'];
    final Map<String, dynamic> data =
        (msg['data'] is Map) ? Map<String, dynamic>.from(msg['data']) : msg;

    // 공통 이벤트
    if (event == 'all_words') {
      setState(() {
        availableWords = List<String>.from(data['data'] ?? const []);
        if (availableWords.isNotEmpty) {
          _wordsLoaded = true; // ✅ 단어 도착 표시
        }
      });
      // 🔥 단어 로딩되면 안내문 자동 종료
      if (_showGuide) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _showGuide = false);
          }
        });
      }

      return;
    }

    if (event == 'room_users' || event == 'room_joined') {
      final users = (data['users'] ?? const []) as List;
      setState(() {
        _roomUsers = users.map(_normId).toList();
        _totalPlayers = _roomUsers.length;
      });
      _maybeFixOrderAndStart();
      return;
    }

    if (event == 'ready_update' || event == 'ready_count') {
      setState(() {
        _readyCount = (data['ready'] ?? data['count'] ?? 0) as int;
        final int? totalFromServer = (data['total'] ?? data['size']) as int?;
        if (totalFromServer != null && totalFromServer > 0) {
          _totalPlayers = totalFromServer;
        }
      });
      _maybeFixOrderAndStart();
      return;
    }

    if (event == 'game_begin') {
      setState(() {
        if (data['order'] != null) {
          _order = (data['order'] as List).map(_normId).toList();
          _orderFixed = true;
          if (_order.isNotEmpty) _totalPlayers = _order.length;
        }
        final act = data['activeUserId'] ?? data['userId'];
        if (act != null) _activeUserId = _normId(act);
        if (_activeUserId == null && _order.isNotEmpty) {
          _activeUserId = _order.first;
        }
        _turnIndex = (data['index'] ?? 0) as int;
        _phase = _Phase.playing;
      });
      if (!_orderFixed) _maybeFixOrderAndStart();
      return;
    }

    if (event == 'turn_start') {
      final current = _normId(data['currentTurn']);
      final List<String> orderRaw =
          (data['turnOrder'] as List? ?? const []).map(_normId).toList();

      // ⏱️ 타이머 정보 받기
      final turnStartTime = data['turnStartTime'] as int?;
      final turnDuration = data['turnDuration'] as int? ?? 20;

      setState(() {
        if (orderRaw.isNotEmpty) {
          _order = orderRaw;
          _orderFixed = true;
          _totalPlayers = _order.length;
        }
        _activeUserId = current.isNotEmpty
            ? current
            : (_order.isNotEmpty ? _order.first : _activeUserId);
        _turnIndex = (_order.isNotEmpty && _activeUserId != null)
            ? _order.indexOf(_activeUserId!)
            : 0;
        if (_turnIndex < 0) _turnIndex = 0;
        _phase = _Phase.playing;
      });

      // ⏱️ 타이머 시작
      if (turnStartTime != null) {
        _startTurnTimer(turnStartTime, turnDuration);
      }

      return;
    }

    if (event == 'turn_update') {
      final current = _normId(data['activeUserId'] ?? data['currentTurn']);
      final List<String> orderRaw =
          (data['order'] ?? data['turnOrder'] ?? const [])
              .map<String>(_normId)
              .toList();

      setState(() {
        if (orderRaw.isNotEmpty) {
          _order = orderRaw;
          _orderFixed = true;
          _totalPlayers = _order.length;
        }
        if (current.isNotEmpty) _activeUserId = current;
        _turnIndex = (_order.isNotEmpty && _activeUserId != null)
            ? _order.indexOf(_activeUserId!)
            : _turnIndex;
        if (_turnIndex < 0) _turnIndex = 0;
        _phase = _Phase.playing;
      });
      return;
    }

    // ====== 승리 브로드캐스트 (highlight_result 바깥으로 둠) ======
    if (event == 'game_over' || event == 'bingo_win') {
      final winner = _normId(data['winner'] ?? data['userId'] ?? '');
      final me = _normId(widget.userId);
      final bool iWon = winner == me;

      if (!_showBingoEffect) {
        _showBingoResultDialog(iWon: iWon);
      } else {
        if (!iWon) {
          Future.delayed(const Duration(milliseconds: 2100), () async {
            if (!_dialogShown) {
              await _showBingoResultDialog(iWon: false);
            }
          });
        }
      }
      return;
    }

    // ====== 하이라이트 시작: 누군가 단어를 눌러 도전 ======
    if (event == 'word_hilight') {
      final String? w = (data['word'] ?? data['data']) as String?;
      if (w != null && w.isNotEmpty) {
        final nw = _normWord(w);
        final bool hasInBoard = _boardHasWord(w);
        final bool alreadyMine = crossedMine.contains(nw);
        final bool alreadyHighlighted = crossedOthers.contains(nw);
        final bool alreadyAttempted = _duplicateWordAttempted.contains(nw);

        print('🟦 word_hilight 수신: word=$w (정규화: $nw)');
        print('   hasInBoard=$hasInBoard, alreadyMine=$alreadyMine');
        print(
            '   alreadyHighlighted=$alreadyHighlighted, alreadyAttempted=$alreadyAttempted');
        print('   Before: crossedOthers=${crossedOthers.toList()}');

        setState(() {
          // 🎯 파란 링 누적 가능 (여러 개 쌓일 수 있음)
          if (!alreadyMine &&
              hasInBoard &&
              !alreadyHighlighted &&
              !alreadyAttempted) {
            // 🎯 중복 단어: 내 보드에 있지만 아직 안 맞춘 경우
            crossedOthers.add(nw);
            _duplicateWordFirstChance[nw] = true;
            _highlightResponded.remove(nw);
            print('   ✨ 파란 링 추가: $nw');
          } else if (!alreadyMine && !hasInBoard) {
            // 내 보드에 없는 단어 → 10초 타이머만 작동
            print('   ⏰ 내 보드에 없음 → 타이머만 시작');
          } else {
            print('   ⏭️ 이미 맞춤/이미 파란 링/이미 시도함 → 무시');
          }
        });

        print('   After: crossedOthers=${crossedOthers.toList()}');

        if (!hasInBoard) {
          _startHighlightDeadline(w);
        }

        if (hasInBoard &&
            !alreadyMine &&
            !alreadyHighlighted &&
            !alreadyAttempted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🟦 중복 단어 도전: "$w"'),
              backgroundColor: const Color(0xFF4E6E99),
            ),
          );
        }
      }
      return;
    }

    // ====== 하이라이트 결과: 턴 주인 제외 인원들의 정답 여부 리스트 ======
    if (event == 'highlight_result') {
      final String? wordRaw = data['word'] as String?;
      if (wordRaw == null || wordRaw.isEmpty) return;
      final String word = wordRaw.trim();
      final String nw = _normWord(word);

      // ✅ 1) 단일 유저 페이로드 지원 (백엔드 현재 형태)
      final String? oneLogin = data['loginId'] as String?;
      final dynamic wordCorrRaw = data['word_corr'];

      if (oneLogin != null) {
        final me = _normId(widget.userId);
        final normOneLogin = _normId(oneLogin);
        final isMe = normOneLogin == me;

        // ⚠️ 엄격한 타입 체크: true일 때만 정답
        final bool oneOk = (wordCorrRaw is bool && wordCorrRaw == true);

        final bool isDuplicateWord = _duplicateWordFirstChance[nw] == true;
        final bool inMyBoard = _boardHasWord(word);
        final bool alreadyMarked = crossedMine.contains(nw);

        print('🔍 highlight_result (단일):');
        print('   word=$word (정규화: $nw)');
        print('   wordKr=${data['wordKr'] ?? 'N/A'}');
        print('   loginId=$oneLogin (정규화: $normOneLogin)');
        print('   userId=${widget.userId} (정규화: $me)');
        print('   ⭐ isMe=$isMe');
        print('   ⭐ word_corr=$wordCorrRaw (type: ${wordCorrRaw.runtimeType})');
        print('   ⭐ oneOk=$oneOk (엄격한 체크 결과)');
        print('   isDuplicateWord=$isDuplicateWord');
        print('   inMyBoard=$inMyBoard');
        print('   alreadyMarked=$alreadyMarked');
        print('   _isMyTurn=$_isMyTurn');
        print('   📋 서버 응답 전체: $data');

        // 🎬 Effect는 내가 답한 경우에만 표시
        if (isMe) {
          print('   🎬 Effect 표시 (본인만): oneOk=$oneOk');
          _showAnswerResultEffect(oneOk, word);
        } else {
          print('   ⏭️ 다른 사람 응답 → Effect 표시 안 함');
          // 🎯 상대방이 시도한 단어가 내 보드에 있으면 중복 표시 추가
          // ⚠️ 단, 이미 중복 표시가 있거나 이미 시도한 중복 단어는 제외
          // ⚠️ 그리고 내가 먼저 시도한 단어도 제외
          if (!crossedMine.contains(nw) &&
              !crossedOthers.contains(nw) &&
              !_duplicateWordAttempted.contains(nw) &&
              !_myAttemptedWords.contains(nw) && // 🎯 내가 먼저 시도한 단어는 제외
              _boardHasWord(word)) {
            setState(() {
              crossedOthers.add(nw);
              _duplicateWordFirstChance[nw] = true;
            });
            print('   🔵 상대 시도! 내 보드에 중복 표시 추가: $nw (정답 여부: $oneOk)');
          } else {
            print(
                '   ℹ️ 상대 시도했지만 중복 표시 안 함 (이유: 이미 맞춤/이미 중복 표시/이미 시도함/내가 먼저 시도함/보드에 없음)');
          }
          return; // 상대방 응답은 여기서 종료
        }

        // ✅ 내가 답한 경우만 보드 상태 업데이트
        setState(() {
          if (oneOk) {
            // ✅ 정답
            if (!alreadyMarked) {
              print('   ✅ 정답! crossedOthers 제거, crossedMine 추가');
              crossedOthers.remove(nw);
              crossedMine.add(nw);
              _duplicateWordFirstChance.remove(nw);
            } else {
              print('   ✅ 정답이지만 이미 있음');
            }
          } else {
            // ❌ 오답 → 파란 링 무조건 제거 (시간 낭비 방지)
            print('   ❌ 오답 처리');
            crossedOthers.remove(nw);
            _duplicateWordFirstChance.remove(nw);
            _duplicateWordAttempted.add(nw);
            print('   🔴 파란 링 제거 (틀렸으므로 재시도 불가): $nw');

            // 이미 X가 있었다면 제거
            if (alreadyMarked) {
              crossedMine.remove(nw);
              print('   🔴 X 제거: $nw');
            }
          }
        });

        _cancelHighlightDeadline(word);

        // 🎯 서버 응답 완료 → 검사 중인 단어 해제
        if (isMe && _wordUnderReview == nw) {
          setState(() {
            _wordUnderReview = null;
            print('   🔓 검사 완료: $nw (이제 다시 클릭 가능)');
          });
        }

        // ✅ 후속 처리
        if (oneOk) {
          print('   ✅ 정답 처리 완료 → X 추가, 빙고 수 체크');
          _checkWinAfterMark(lastWord: word);

          // 🎯 중복 단어는 턴을 소비하지 않음
          if (isDuplicateWord) {
            print('   🎉 중복 단어 정답! 턴 유지');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ 중복 단어 정답! 턴을 소비하지 않아 계속 시도할 수 있습니다.'),
                backgroundColor: Color(0xFF4E6E99),
                duration: Duration(seconds: 2),
              ),
            );
            // turnDone 안 보냄 (턴 유지)
          } else {
            // 일반 정답: 턴 종료
            print('   📤 일반 정답 → turnDone 전송');
            if (_isMyTurn) {
              widget.socket.sendTurnDone(widget.roomId, widget.userId);
            }
          }
        } else {
          print('   ❌ 오답 처리 완료 → 중복 표시/X 제거');
          // ❌ 오답: 빙고 수 재계산
          if (alreadyMarked) {
            final newCount = _recalcMyBingos();
            if (newCount != _myBingoCount) {
              setState(() => _myBingoCount = newCount);
              print('   🔴 빙고 수 감소: ${_myBingoCount} → $newCount');
            }
          }

          // 🎯 중복 단어는 턴을 소비하지 않음
          if (isDuplicateWord) {
            print('   💡 중복 단어 오답! 턴 유지');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ 중복 단어 오답! 턴을 소비하지 않아 계속 시도할 수 있습니다.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
            // turnDone 안 보냄 (턴 유지)
          } else {
            // 일반 오답: 턴 종료
            print('   📤 일반 오답 → turnDone 전송');
            if (_isMyTurn) {
              widget.socket.sendTurnDone(widget.roomId, widget.userId);
            }
          }
        }

        return; // ← 단일 유저 처리 끝
      }

      // ✅ 2) (기존) results(Map/List) 처리 분기
      final dynamic raw = data['results'];
      final Set<String> winners = {};

      // ⚠️ 엄격한 정답 체크
      if (raw is Map) {
        raw.forEach((k, v) {
          // v가 bool이고 true일 때만 정답
          if (v is bool && v == true) {
            winners.add(_normId(k));
          }
        });
      } else if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            final okRaw = e['ok'];
            final correctRaw = e['correct'];
            final isCorrectRaw = e['isCorrect'];

            // ⚠️ 엄격한 체크: bool이고 true일 때만
            final ok = (okRaw is bool && okRaw == true) ||
                (correctRaw is bool && correctRaw == true) ||
                (isCorrectRaw is bool && isCorrectRaw == true);

            if (ok) {
              winners.add(_normId(e['loginId'] ?? e['userId'] ?? ''));
            }
          }
        }
      }

      final me = _normId(widget.userId);
      final bool iWon = winners.contains(me);
      final bool isDuplicateWord = _duplicateWordFirstChance[nw] == true;
      final bool alreadyMarked = crossedMine.contains(nw);
      final bool inMyBoard = _boardHasWord(word);

      print('🔍 highlight_result (results):');
      print('   word=$word (정규화: $nw)');
      print('   raw=$raw');
      print('   winners=$winners');
      print('   me=$me, iWon=$iWon');
      print('   isDuplicateWord=$isDuplicateWord');
      print('   alreadyMarked=$alreadyMarked');
      print('   📋 서버 응답 전체: $data');

      // 🎬 Effect는 내가 답한 경우에만 표시
      final bool isMyAnswer = iWon || (winners.isEmpty && inMyBoard);
      if (isMyAnswer) {
        if (iWon) {
          print('   🎬 Effect 표시 (정답)');
          _showAnswerResultEffect(true, word);
        } else {
          print('   🎬 Effect 표시 (오답)');
          _showAnswerResultEffect(false, word);
        }
      } else {
        print('   ⏭️ 다른 사람 응답 → Effect 안 함');
        return;
      }

      // ✅ 보드 상태 업데이트
      setState(() {
        if (iWon) {
          // ✅ 정답
          if (!alreadyMarked) {
            crossedOthers.remove(nw);
            crossedMine.add(nw);
            _duplicateWordFirstChance.remove(nw);
            print('   ✅ 정답 처리');
          }
        } else {
          // ❌ 오답 → 파란 링 무조건 제거 (시간 낭비 방지)
          print('   ❌ 오답 처리');
          crossedOthers.remove(nw);
          _duplicateWordFirstChance.remove(nw);
          _duplicateWordAttempted.add(nw);
          print('   🔴 파란 링 제거 (틀렸으므로 재시도 불가)');

          // X 제거
          if (alreadyMarked) {
            crossedMine.remove(nw);
            print('   🔴 X 제거');
          }
        }
      });

      _cancelHighlightDeadline(word);

      // 🎯 서버 응답 완료 → 검사 중인 단어 해제
      if (isMyAnswer && _wordUnderReview == nw) {
        setState(() {
          _wordUnderReview = null;
          print('   🔓 검사 완료: $nw (이제 다시 클릭 가능)');
        });
      }

      // ✅ 후속 처리
      if (iWon) {
        _checkWinAfterMark(lastWord: word);

        // 🎯 중복 단어는 턴을 소비하지 않음
        if (isDuplicateWord) {
          print('   🎉 중복 단어 정답! 턴 유지');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 중복 단어 정답! 턴을 소비하지 않아 계속 시도할 수 있습니다.'),
              backgroundColor: Color(0xFF4E6E99),
            ),
          );
        } else {
          if (_isMyTurn) {
            widget.socket.sendTurnDone(widget.roomId, widget.userId);
          }
        }
      } else {
        // 오답: 빙고 수 재계산
        if (alreadyMarked) {
          final newCount = _recalcMyBingos();
          if (newCount != _myBingoCount) {
            setState(() => _myBingoCount = newCount);
          }
        }

        // 🎯 중복 단어는 턴을 소비하지 않음
        if (isDuplicateWord) {
          print('   💡 중복 단어 오답! 턴 유지');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 중복 단어 오답! 턴을 소비하지 않아 계속 시도할 수 있습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          if (_isMyTurn) {
            widget.socket.sendTurnDone(widget.roomId, widget.userId);
          }
        }
      }

      return;
    }

    // ====== 턴 종합 결과 ======
    if (event == 'next_turn') {
      final String? prevUser = data['prev_user'];
      final String? nextUser = data['next_user'];
      final String? word = data['word'];

      // ⏱️ 타이머 정보 받기
      final turnStartTime = data['turnStartTime'] as int?;
      final turnDuration = data['turnDuration'] as int? ?? 20;

      // ⚠️ 엄격한 타입 체크: true일 때만 정답
      final wordCorrRaw = data['word_corr'];
      final bool correct = (wordCorrRaw is bool && wordCorrRaw == true);

      print('🔍 next_turn: word=$word, prevUser=$prevUser, nextUser=$nextUser');
      print('   ⭐ word_corr=$wordCorrRaw (type: ${wordCorrRaw.runtimeType})');
      print('   ⭐ correct=$correct (엄격한 체크 결과)');
      print('   📋 서버 응답 전체: $data');

      if (word != null && word.isNotEmpty) {
        final nw = _normWord(word);
        final me = _normId(widget.userId);
        final prevIsMe = _normId(prevUser) == me;
        final isDuplicateWord = _duplicateWordFirstChance[nw] == true;
        final alreadyMarked = crossedMine.contains(nw);

        print('   → prevIsMe=$prevIsMe, me=$me');
        print(
            '   → isDuplicateWord=$isDuplicateWord, alreadyMarked=$alreadyMarked');

        // 🎬 Effect는 내가 답한 경우에만 표시
        if (prevIsMe) {
          print('   🎬 Effect 표시 (본인만): correct=$correct');
          _showAnswerResultEffect(correct, word);
        } else {
          print('   ⏭️ 다른 사람 응답이므로 Effect 표시 안 함');
        }

        setState(() {
          if (correct && prevIsMe) {
            // ✅ 내가 턴에서 맞춘 경우만 → 내 보드에 X 표시
            if (!crossedMine.contains(nw)) {
              print('   ✅ 정답! crossedMine 추가: $nw');
              crossedOthers.remove(nw);
              crossedMine.add(nw);
              _duplicateWordFirstChance.remove(nw);
            } else {
              print('   ✅ 이미 crossedMine에 있음 (중복 방지)');
            }
          } else if (!correct && prevIsMe) {
            // ❌ 내가 오답 → 파란 링 무조건 제거 (시간 낭비 방지)
            print('   ❌ 오답 처리 (내가 틀림)');
            crossedOthers.remove(nw);
            _duplicateWordFirstChance.remove(nw);
            _duplicateWordAttempted.add(nw);
            print('   🔴 파란 링 제거 (틀렸으므로 재시도 불가): $nw');

            // X 제거
            if (alreadyMarked) {
              crossedMine.remove(nw);
              print('   🔴 X 제거: $nw');
            }
          } else if (!prevIsMe) {
            // 🎯 상대방이 단어를 시도한 경우 (정답/오답 무관)
            // → 내 보드에 같은 단어가 있으면 중복 표시(파란 링) 추가
            // ⚠️ 단, 이미 중복 표시가 있거나 이미 시도한 중복 단어는 제외
            // ⚠️ 그리고 내가 먼저 시도한 단어도 제외
            if (!crossedMine.contains(nw) &&
                !crossedOthers.contains(nw) &&
                !_duplicateWordAttempted.contains(nw) &&
                !_myAttemptedWords.contains(nw) && // 🎯 내가 먼저 시도한 단어는 제외
                _boardHasWord(word)) {
              crossedOthers.add(nw);
              _duplicateWordFirstChance[nw] = true;
              print('   🔵 상대 시도! 내 보드에 중복 표시 추가: $nw (정답 여부: $correct)');
            } else {
              print(
                  '   ℹ️ 상대 시도했지만 중복 표시 안 함 (이유: 이미 맞춤/이미 중복 표시/이미 시도함/내가 먼저 시도함/보드에 없음)');
            }
          }

          // 턴 이동 갱신
          if (nextUser != null && nextUser.isNotEmpty) {
            _activeUserId = _normId(nextUser);
            final idx = _order.indexOf(_activeUserId!);
            if (idx >= 0) _turnIndex = idx;
            print('   🔄 턴 이동: $_activeUserId (index: $_turnIndex)');
          }
        });

        // 🎯 서버 응답 완료 → 검사 중인 단어 해제
        if (prevIsMe && _wordUnderReview == nw) {
          setState(() {
            _wordUnderReview = null;
            print('   🔓 검사 완료: $nw (이제 다시 클릭 가능)');
          });
        }

        // 승리 체크 (setState 밖에서)
        if (correct && prevIsMe) {
          _checkWinAfterMark(lastWord: word);
        } else if (!correct && prevIsMe) {
          // 오답: 빙고 수 재계산
          if (alreadyMarked) {
            final newCount = _recalcMyBingos();
            if (newCount != _myBingoCount) {
              setState(() => _myBingoCount = newCount);
              print('   🔴 빙고 수 감소: ${_myBingoCount} → $newCount');
            }
          }
        }

        // ❌ 제거됨: next_turn에서는 하이라이트 타이머 시작 안 함
        // 이유: 일반 턴 모드에서는 하이라이트 시스템이 작동하지 않음
        // 하이라이트는 word_hilight 이벤트에서만 처리됨
      }

      // ⏱️ 타이머 시작
      if (turnStartTime != null) {
        _startTurnTimer(turnStartTime, turnDuration);
      }

      return;
    }

    // ====== 레거시 이벤트 호환 ======
    if (event == 'opponent_word' ||
        event == 'mark_word' ||
        event == 'word_click' ||
        event == 'opponent_click') {
      final String? w = (data['word'] ?? data['data']) as String?;
      if (w != null && w.isNotEmpty) {
        final nw = _normWord(w);
        setState(() {
          if (!crossedMine.contains(nw)) {
            crossedOthers.add(nw);
          }
        });
      }
      return;
    }
  }

  bool get _isBoardFilled {
    for (var row in bingoBoard) {
      if (row.contains(null)) return false;
    }
    return true;
  }

  void _checkBoardReady() {
    setState(() {
      _boardFilled = _isBoardFilled;
    });
  }

  void _sendReady() {
    if (_iAmReady) return;
    widget.socket.sendBoardReady(widget.roomId, userId: widget.userId);
    setState(() => _iAmReady = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 준비 완료! 상대방을 기다리는 중...')),
    );
  }

  void _autoFillBoard25() {
    if (availableWords.length < 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '자동 채우기에는 최소 25개의 단어가 필요해요. (현재: ${availableWords.length})')),
      );
      return;
    }

    // 25개 랜덤 추출
    final pool = List<String>.from(availableWords)..shuffle(Random());
    final chosen = pool.take(25).toList();

    setState(() {
      // 보드 리셋 후 25칸 채우기
      for (int r = 0, k = 0; r < 5; r++) {
        for (int c = 0; c < 5; c++, k++) {
          bingoBoard[r][c] = chosen[k];
        }
      }
      // 사용한 단어는 칩 풀에서 제거
      availableWords.removeWhere((w) => chosen.contains(w));
    });

    _checkBoardReady();
  }

  Future<String> loadOrCreateUid() async {
    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString('bingo_uid');
    if (uid == null || uid.isEmpty) {
      uid =
          '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}';
      await prefs.setString('bingo_uid', uid);
    }
    return uid;
  }

  Future<void> _showBingoResultDialog({required bool iWon}) async {
    if (_dialogShown) return;
    _dialogShown = true;

    // 게임 종료 상태로 전환 (중복 방지)
    if (_phase != _Phase.ended) {
      setState(() => _phase = _Phase.ended);
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 350,
          height: 350,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/dialog1.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  iWon ? "🎉 승리!" : "게임 종료",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  iWon ? "3빙고를 먼저 달성했습니다!" : "상대가 3빙고를 먼저 달성했습니다.",
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 35),
                ElevatedButton(
                  onPressed: () {
                    // 1) 다이얼로그 먼저 닫기
                    Navigator.of(context).pop();

                    // 2) 다음 프레임(마이크로태스크)에서 2페이지 뒤로 가기
                    Future.microtask(() {
                      int popCount = 0;
                      Navigator.of(context)
                          .popUntil((route) => popCount++ >= 2);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iWon
                        ? const Color(0xFF4E6E99)
                        : const Color(0xFFFCC8C8),
                    foregroundColor: iWon ? Colors.white : Colors.black,
                    minimumSize: const Size(120, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTapOnCell(String word) async {
    final nw = _normWord(word);

    // 🚫 이 단어가 현재 검사 중이면 차단 (중복 제출 방지)
    if (_wordUnderReview == nw) {
      print('⛔ 검사 중인 단어 → 중복 클릭 차단: $word');
      return;
    }

    // 🎯 클릭 시점에 파란 링 여부 저장 (퀴즈 풀고 오는 동안 변할 수 있음)
    final bool wasHighlightedAtClick = crossedOthers.contains(nw);
    final bool alreadyAttemptedAtClick = _duplicateWordAttempted.contains(nw);
    final bool alreadyMarked = crossedMine.contains(nw);

    print('🎯 단어 선택: $word');
    print('   wasHighlightedAtClick=$wasHighlightedAtClick');
    print('   alreadyAttemptedAtClick=$alreadyAttemptedAtClick');
    print('   alreadyMarked=$alreadyMarked');
    print('   _isMyTurn=$_isMyTurn');

    // 🎯 파란 링 중복 클릭 방지: 즉시 기록 (퀴즈 들어가기 전에!)
    final bool useDuplicateChance =
        wasHighlightedAtClick && !alreadyAttemptedAtClick;
    if (useDuplicateChance) {
      setState(() {
        _duplicateWordAttempted.add(nw);
        print('   📝 중복 단어 기회 사용 시작: $nw (중복 클릭 방지)');
      });
    }

    final QuizResult? result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute(
        builder: (_) => BingoQuiz(
          word: word,
          initialSeconds: _remainingSeconds > 0 ? _remainingSeconds : 20,
        ),
      ),
    );

    if (result == null) {
      print('   취소됨');
      // 🎯 취소했으면 기록도 취소
      if (useDuplicateChance) {
        setState(() {
          _duplicateWordAttempted.remove(nw);
          print('   ↩️ 취소: 중복 단어 기회 복원');
        });
      }
      return;
    }

    print('   답변: ${result.answer}');

    // 🎯 내가 시도한 단어 기록 (중복 표시 방지용)
    _myAttemptedWords.add(nw);
    print('   📝 내가 시도한 단어 기록: $nw');

    // 🎯 클릭 시점에 파란 링이 있고 아직 시도 안 했으면 word_hilight (턴 소비 절대 안 함!)
    // 백엔드는 event 필드만 보고 판단: word_click=턴소비, word_hilight=턴유지
    final String eventName = useDuplicateChance ? 'word_hilight' : 'word_click';

    print('   이벤트: $eventName');
    print(
        '   이유: ${useDuplicateChance ? "중복 단어 기회 (파란 링, 턴 소비 없음!)" : (_isMyTurn ? "내 차례 (일반 단어)" : "일반 단어")}');

    // 🎯 검사 시작: 이 단어는 서버 응답까지 클릭 불가
    setState(() {
      _wordUnderReview = nw;
      print('   🔒 검사 시작: $nw (서버 응답까지 이 단어만 클릭 차단)');
    });

    widget.socket.sendUserWordEvent(
      roomId: widget.roomId,
      loginId: widget.userId,
      event: eventName,
      word: word,
      wordKr: result.answer,
      wasHighlighted: wasHighlightedAtClick,
    );

    if (wasHighlightedAtClick && !_isMyTurn) {
      _cancelHighlightDeadline(word);
    }

    print('   서버 응답 대기 중... (다른 단어는 클릭 가능)');
  }

  @override
  Widget build(BuildContext context) {
    // 세팅 단계에서만 보드 고정(내가 '준비완료' 누르면 더 못 움직임),
    // 종료 상태에서도 입력 금지
    final absorbingBoard =
        _phase == _Phase.setup ? _iAmReady : (_phase == _Phase.ended);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 20),

              // ⏱️ 턴 정보 및 타이머
              if (_phase == _Phase.playing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 현재 턴 표시
                      Text(
                        _isMyTurn ? '내 차례' : '상대 차례',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              _isMyTurn ? const Color(0xFF4E6E99) : Colors.grey,
                        ),
                      ),
                      // 남은 시간 표시
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _remainingSeconds <= 5
                              ? Colors.red.withOpacity(0.1)
                              : const Color(0xFF4E6E99).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _remainingSeconds <= 5
                                ? Colors.red
                                : const Color(0xFF4E6E99),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer,
                              size: 20,
                              color: _remainingSeconds <= 5
                                  ? Colors.red
                                  : const Color(0xFF4E6E99),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_remainingSeconds}초',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _remainingSeconds <= 5
                                    ? Colors.red
                                    : const Color(0xFF4E6E99),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 빙고 보드
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      AbsorbPointer(
                        absorbing: absorbingBoard,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(6),
                          itemCount: 25,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final r = index ~/ 5;
                            final c = index % 5;
                            final String? cellWord = bingoBoard[r][c];
                            final bool isFilled = cellWord != null;

                            final bool isMineMarked = isFilled &&
                                crossedMine.contains(_normWord(cellWord));
                            final bool isOthersMarked = isFilled &&
                                crossedOthers.contains(_normWord(cellWord));

                            return DragTarget<DragWord>(
                              onWillAccept: (_) => true,
                              onAccept: (drag) {
                                setState(() {
                                  final prev = bingoBoard[r][c];
                                  if (prev != null && prev.isNotEmpty) {
                                    availableWords.add(prev);
                                  }
                                  bingoBoard[r][c] = drag.word;
                                  if (drag.fromBoard) {
                                    final sr = drag.srcRow!;
                                    final sc = drag.srcCol!;
                                    if (!(sr == r && sc == c)) {
                                      bingoBoard[sr][sc] = null;
                                    }
                                  } else {
                                    availableWords.remove(drag.word);
                                  }
                                });
                                _checkBoardReady();
                              },
                              builder: (context, candidate, _) {
                                final bool isHover = candidate.isNotEmpty;

                                return LayoutBuilder(
                                  builder: (_, constraints) {
                                    final d =
                                        constraints.biggest.shortestSide * 0.9;

                                    final innerCore = Container(
                                      width: d,
                                      height: d,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isFilled
                                            ? const Color(0xFFCDE4F2)
                                            : const Color(0xFFFCC8C8),
                                        border: Border.all(
                                          color: const Color(0xFF4E6E99),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: isHover ? 6 : 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // 단어 텍스트
                                          Text(
                                            cellWord ?? '',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4E6E99),
                                            ),
                                          ),

                                          // 내가 맞춘 칸: 굵은 빨간 X
                                          if (isMineMarked)
                                            Text(
                                              'X',
                                              style: TextStyle(
                                                fontSize: d * 0.45,
                                                fontWeight: FontWeight.w900,
                                                color:
                                                    Colors.red.withOpacity(0.9),
                                                shadows: const [
                                                  Shadow(
                                                      blurRadius: 2,
                                                      color: Colors.black26),
                                                ],
                                              ),
                                            ),

                                          // 남이 맞춘(나는 아직) 칸: 파란 링 + 투명 체크
                                          if (!isMineMarked && isOthersMarked)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF4E6E99)
                                                            .withOpacity(0.85),
                                                    width: 3.0,
                                                  ),
                                                  color: const Color(0xFF4E6E99)
                                                      .withOpacity(0.12),
                                                ),
                                              ),
                                            ),
                                          if (!isMineMarked && isOthersMarked)
                                            Icon(
                                              Icons.check_circle,
                                              size: d * 0.32,
                                              color: const Color(0xFF4E6E99)
                                                  .withOpacity(0.9),
                                            ),
                                        ],
                                      ),
                                    );
                                    // 자기 차례 아니어도 하이라이트된 단어 클릭 가능
                                    final canTap = _phase == _Phase.playing &&
                                        isFilled &&
                                        !isMineMarked &&
                                        (_isMyTurn || isOthersMarked);

                                    final tappableInner = GestureDetector(
                                      onTap: !canTap
                                          ? null
                                          : () => _handleTapOnCell(cellWord!),
                                      child: innerCore,
                                    );

                                    // 드래그는 세팅 단계에서만 허용 (게임 시작 후 이동 불가)
                                    if (_phase == _Phase.setup && isFilled) {
                                      final word = cellWord!;
                                      return Center(
                                        child: Draggable<DragWord>(
                                          data: DragWord(word,
                                              srcRow: r, srcCol: c),
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.yellow,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        const Color(0xFF4E6E99),
                                                    width: 2),
                                              ),
                                              child: Text(
                                                word,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: Opacity(
                                              opacity: 0.25,
                                              child: tappableInner),
                                          onDragStarted: () {
                                            setState(() {
                                              bingoBoard[r][c] = null;
                                            });
                                          },
                                          onDragEnd: (details) {
                                            if (!details.wasAccepted) {
                                              setState(() {
                                                bingoBoard[r][c] = word;
                                              });
                                            }
                                          },
                                          child: tappableInner,
                                        ),
                                      );
                                    } else {
                                      // 플레이/종료 단계: 드래그 금지, 탭만 허용
                                      return Center(child: tappableInner);
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
              const Divider(height: 1),

              // 하단 영역 (턴 배지 + 컨트롤)
              SizedBox(
                height: 150,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (_activeUserId != null)
                        _TurnBadge(
                          isMine: _isMyTurn,
                          orderText: _order.isNotEmpty
                              ? '순서 ${_turnIndex + 1}/${_order.length}'
                              : null,
                        ),
                      if (_phase != _Phase.setup)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '내 빙고: $_myBingoCount',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4E6E99),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _phase == _Phase.setup
                            ? (_boardFilled
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 220,
                                        child: ElevatedButton(
                                          onPressed:
                                              _iAmReady ? null : _sendReady,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF4E6E99),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: Text(
                                            _iAmReady ? '준비 완료' : '빙고 시작',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_totalPlayers > 0)
                                        Text(
                                          '대기중: $_readyCount / $_totalPlayers',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF4E6E99),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1) 칩들이 먼저 한 줄로 뜨도록, 고정 높이 부여
                                      SizedBox(
                                        height: 60, // 칩 한 줄 높이
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Row(
                                            children: availableWords.map((w) {
                                              return Draggable<DragWord>(
                                                data: DragWord(w),
                                                feedback: Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    color: Colors.yellow,
                                                    child: Text(
                                                      w,
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                                childWhenDragging: Opacity(
                                                    opacity: 0.3,
                                                    child: _wordChip(w)),
                                                child: _wordChip(w),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // 2) 칩이 있을 때만, '칩 밑에' 자동 채우기 버튼 (가운데 정렬)
                                      if (availableWords.isNotEmpty)
                                        Center(
                                          child: SizedBox(
                                            width: 170,
                                            height: 40,
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  availableWords.length >= 25
                                                      ? _autoFillBoard25
                                                      : null,
                                              icon: const Icon(
                                                Icons.auto_fix_high_rounded,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                '자동 채우기 (25개)',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF4E6E99),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ))
                            : Center(
                                child: Text(
                                  _phase == _Phase.ended
                                      ? '게임 종료'
                                      : (_isMyTurn
                                          ? '당신의 차례입니다. 칸을 선택하세요.'
                                          : '상대 차례입니다.'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4E6E99),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 🔹 퀴즈 정답/실패 이펙트
          if (_showAnswerEffect)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(0.12),
                  child: BingoEffect(
                    key: const ValueKey('answerEffect'), // 👉 추가
                    isCorrect: _lastAnswerCorrect,
                    onEnd: () {
                      if (!mounted) return;
                      setState(() {
                        _showAnswerEffect = false;

                        // 🔸 정답 이펙트 끝났을 때, 예약된 빙고 이펙트가 있으면 실행
                        if (_queuedBingoCount != null) {
                          _effectCount = _queuedBingoCount!.clamp(1, 3);
                          _showBingoEffect = true;
                          _lastShownEffect = _queuedBingoCount!;
                          _queuedBingoCount = null;
                        }
                      });
                    },
                  ),
                ),
              ),
            ),

// ===== 빙고 이펙트 오버레이 =====
          if (_showBingoEffect)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(0.15),
                  child: BingoEffect(
                    key: const ValueKey('bingoEffect'),
                    bingoCount: _effectCount,
                    onEnd: () async {
                      if (!mounted) return;
                      setState(() => _showBingoEffect = false);

                      if (_winAnnounced &&
                          _myBingoCount >= 3 &&
                          !_dialogShown) {
                        await _showBingoResultDialog(iWon: true);
                      }
                    },
                  ),
                ),
              ),
            ),
          // 🔹 처음 입장 시 전체 안내 오버레이
          if (_showGuide)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45), // 배경색 (네 앱 톤에 맞게)
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '빙고 게임 안내',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // 👉 여기에 네가 쓰고 싶은 "게임 방법" 전체 설명 넣으면 됨
                        const Text(
                          '1. 아래 단어 칩을 드래그해서 5x5 빙고판을 채워주세요.\n 혹은 자동 채우기를 눌러서 빙고를 채울 수 있어요.\n\n'
                          '2. 준비가 되면 [빙고 시작] 버튼을 눌러 게임을 시작해요.\n\n'
                          '3. 자신의 차례에는 빙고판의 단어를 선택해 퀴즈를 풀고,\n'
                          '   정답이면 해당 칸에 X가 표시됩니다.\n\n'
                          '4. 가로, 세로, 대각선으로 3줄을 먼저 완성하면 승리!\n'
                          '※ : 체크된 표시는 다른 사용자가 맞춘 퀴즈입니다. \n      자신의 차례가 아닐 때에도 맞춰볼 수 있습니다.',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.6,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordChip(String w) => Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(w),
      );
}
