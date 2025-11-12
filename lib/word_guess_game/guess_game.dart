// guess_game.dart
import 'package:flutter/material.dart';
import 'guess_effect.dart';

class GuessGamePage extends StatefulWidget {
  const GuessGamePage({Key? key}) : super(key: key);

  @override
  State<GuessGamePage> createState() => _GuessGamePageState();
}

class _GuessGamePageState extends State<GuessGamePage> {
  String _questionText = '문제가 여기에 들어갑니다';

  // 임시 정답 (나중에 서버/문제 리스트에서 받아오면 됨)
  String _correctAnswer = 'apple';

  // 정답 입력용 컨트롤러
  final TextEditingController _answerController = TextEditingController();

  // 점수 & 정보창 메시지
  int _score = 0;
  String _statusMessage = 'Type the correct word as fast as you can!';

  int _correctCount = 0;
  final int _maxKeys = 46;

  static const Color _bgColor = Color(0xFFF6F0E9);
  static const Color _primary = Color(0xFF213654);
  static const Color _keyDefault = Colors.white;
  static const Color _keyCorrect = Color(0xFF4CAF50);

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  // 결과 연출(You had it / You missed it) 띄우기
  void _showGuessEffect(GuessResultType type) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // 뒤 화면 비치게
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: GuessEffectPage(
              resultType: type,
              duration: const Duration(seconds: 2), // 2초 보여주고 자동 닫힘
            ),
          );
        },
      ),
    );
  }

  void _submitAnswer() {
    final answer = _answerController.text.trim();

    if (answer.isEmpty) {
      setState(() {
        _statusMessage = '아무 것도 입력하지 않았어요 😅 단어를 입력해 주세요!';
      });
      // 2초 후 원래 문구로 복귀
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _statusMessage = 'Type the correct word as fast as you can!';
          });
        }
      });
      return;
    }

    // ✅ 먼저 정답 여부 계산
    final bool isCorrect = answer.toLowerCase() == _correctAnswer.toLowerCase();

    setState(() {
      if (isCorrect) {
        const gained = 10;
        _score += gained;
        _statusMessage = '✅ 정답! +$gained점 얻었어요 🎉 (현재 점수: $_score점)';

        if (_correctCount < _maxKeys) {
          _correctCount++;
        }
      } else {
        _statusMessage = '❌ 틀렸어요 😢 정답은 "$_correctAnswer"였어요.';
      }
    });

    // ✅ 여기서 효과 페이지 띄우기
    _showGuessEffect(
      isCorrect ? GuessResultType.hadIt : GuessResultType.missedIt,
    );

    // ✅ 2초 후 원래 메시지로 자동 복귀
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Type the correct word as fast as you can!';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 상단 상태 영역 (게임 이름 + 점수)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  const Icon(Icons.computer, color: _primary, size: 24),
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
                  // 점수 표시 뱃지
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Score: $_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 컴퓨터(모니터 + 받침대 + 키보드) 영역
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildComputer(), // 🖥️ 모니터 + ㅗ 받침대 + 키보드
                    const SizedBox(height: 32),
                    _buildAnswerArea(), // 입력창 + 버튼
                  ],
                ),
              ),
            ),

            // 책상 느낌 하단 바 + 정보창
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

  /// 🖥️ 컴퓨터 전체(모니터 + 받침대 + 키보드)
  Widget _buildComputer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🖥 모니터 부분
        Stack(
          alignment: Alignment.center,
          children: [
            // 바깥 케이스/그림자
            Container(
              width: double.infinity,
              height: 195,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(36),
              ),
            ),

            // 실제 모니터 화면
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _primary,
                  width: 18,
                ),
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
                  // 위 상태바
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
                        child: Text(
                          _questionText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E2A1C),
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

        // 🔽 여기부터 ㅗ 받침대 전체를 위로 살짝 끌어올려서 모니터랑 딱 붙이기
        Transform.translate(
          offset: const Offset(0, -8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 세로 기둥
              Container(
                width: 42,
                height: 28,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 2),
              // 가로 받침대 (ㅗ)
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

        // ✅ 키보드 (1줄 23개, 작은 네모 크기 고정 + 세로 중앙 정렬)
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Center(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(), // 스크롤 안 되게
              shrinkWrap: true, // 내용 크기만큼만 차지
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 23, // 👉 한 줄에 23개 고정
                crossAxisSpacing: 4, // 가로 간격
                mainAxisSpacing: 4, // 세로 간격
              ),
              itemCount: _maxKeys, // 👉 46개니까 2줄 딱
              itemBuilder: (context, index) {
                final isFilled = index < _correctCount;
                return Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 14, // ✅ 네모 크기 고정
                    height: 10, // ✅ 네모 크기 고정
                    decoration: BoxDecoration(
                      color:
                          isFilled ? _keyCorrect : _keyDefault.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// ✏️ 정답 입력창 + 확인 버튼
  Widget _buildAnswerArea() {
    return Column(
      children: [
        TextField(
          controller: _answerController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitAnswer(),
          decoration: InputDecoration(
            hintText: '정답을 입력하세요',
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _primary,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _primary,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _primary,
                width: 2,
              ),
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
            onPressed: _submitAnswer,
            child: const Text(
              '확인',
              style: TextStyle(
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
