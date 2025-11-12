import 'dart:async';
import 'package:flutter/material.dart';

/// Bingo 셀을 눌렀을 때 띄우는 퀴즈 페이지.
/// 결과는 항상 QuizResult(ok, answer)로 반환됨
class BingoQuiz extends StatefulWidget {
  final String word;

  /// 자동 채점용 정답 모음 (선택, 대소문자/공백 무시 비교)
  final Set<String>? correctAnswers;

  /// 사용자 정의 검증 함수 (선택)
  final Future<bool> Function(String word, String answer)? validator;

  /// 문제 설명/지문/힌트 (선택)
  final String? prompt;

  const BingoQuiz({
    super.key,
    required this.word,
    this.correctAnswers,
    this.validator,
    this.prompt,
  });

  @override
  State<BingoQuiz> createState() => _BingoQuizState();
}

/// ✅ 퀴즈 결과 DTO
class QuizResult {
  final bool ok; // 정답 여부
  final String answer; // 사용자가 입력/선택한 값(= wordKr로 전송)
  const QuizResult({required this.ok, required this.answer});
}

class _BingoQuizState extends State<BingoQuiz> {
  final _inputCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;

  // ⏱️ 제한시간 10초
  static const int _limit = 10;
  int _secsLeft = _limit;
  Timer? _timer;
  bool _finished = false;

  bool get _hasAutoJudge =>
      (widget.correctAnswers != null && widget.correctAnswers!.isNotEmpty) ||
      widget.validator != null;

  @override
  void initState() {
    super.initState();
    // 제한시간 타이머 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secsLeft--;
        if (_secsLeft <= 0) {
          _finishWithTimeout();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // 문자열 정규화
  String _norm(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  // ⏱️ 시간초과 시 공백 wordKr 전송
  void _finishWithTimeout() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    Navigator.of(context).pop(const QuizResult(ok: false, answer: " "));
  }

  // 정상 제출
  void _finishWithResult(QuizResult res) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    Navigator.of(context).pop(res);
  }

  // ✅ 주관식 제출
  Future<void> _submitShortAnswer() async {
    if (_submitting || _finished) return;

    final ans = _inputCtrl.text.trim();
    if (ans.isEmpty) {
      _showSnack('정답을 입력해 주세요.', isWarn: true);
      return;
    }

    setState(() => _submitting = true);
    bool ok = false;

    try {
      if (widget.validator != null) {
        ok = await widget.validator!(widget.word, ans);
      } else if (widget.correctAnswers != null &&
          widget.correctAnswers!.isNotEmpty) {
        final target = _norm(ans);
        ok = widget.correctAnswers!.map(_norm).contains(target);
      } else {
        ok = false;
      }
    } catch (e) {
      _showSnack('채점 중 오류: $e', isWarn: true);
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    _finishWithResult(QuizResult(ok: ok, answer: ans));
  }

  void _showSnack(String msg, {bool isWarn = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isWarn ? Colors.redAccent : const Color(0xFF4E6E99),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF4E6E99);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        // ⏱️ 상단 타이머
        title: Row(
          children: [
            const Text('빙고 퀴즈'),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.timer, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text('$_secsLeft s',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 문제 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDE4F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeColor, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('단어',
                        style: TextStyle(
                            color: themeColor, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      widget.word,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                      ),
                    ),
                    if (widget.prompt != null &&
                        widget.prompt!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.prompt!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 주관식 입력 영역
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeColor.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('정답을 입력하세요'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _inputCtrl,
                      focusNode: _focus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitShortAnswer(),
                      decoration: InputDecoration(
                        hintText: '여기에 입력',
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submitShortAnswer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline,
                                color: Colors.white),
                        label: Text(_submitting ? '확인 중...' : '확인'),
                      ),
                    ),
                    if (!_hasAutoJudge) ...[
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
