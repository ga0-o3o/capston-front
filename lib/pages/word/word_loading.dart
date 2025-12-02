import 'dart:async';
import 'package:flutter/material.dart';
import 'word_api.dart';
import 'package:gif_view/gif_view.dart';

class WordLoadingPage extends StatefulWidget {
  final Future<void> Function() task;

  const WordLoadingPage({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  State<WordLoadingPage> createState() => _WordLoadingPageState();
}

class _WordLoadingPageState extends State<WordLoadingPage> {
  Map<String, String>? words;
  String? selectedEn;
  String? selectedKr;
  Set<String> matched = {};

  bool loadingNext = false;
  bool alreadyPopped = false; // pop 중복 방지

  List<String> _krList = [];

  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  /// 🔥 로딩 시작 + task 실행 + 종료 처리
  Future<void> _startProcess() async {
    // 랜덤 단어 첫 로딩
    await _fetchRandomWords();

    // OCR 등 실제 작업 실행
    try {
      await widget.task(); // <-- task가 끝나는 순간 로딩 종료
    } finally {
      _safePop(); // <-- 단 한 번만 pop
    }
  }

  /// 🔥 pop 안전 처리 (중복 pop 방지)
  void _safePop() {
    if (!mounted) return;
    if (alreadyPopped) return;
    alreadyPopped = true;

    Navigator.of(context).pop();
  }

  /// 랜덤 단어 가져오기 (1회 + 전부 맞추면 다시 요청)
  Future<void> _fetchRandomWords() async {
    final result = await WordApi.fetchRandomWords();
    if (!mounted) return;

    setState(() {
      words = result;
      selectedEn = null;
      selectedKr = null;
      matched.clear();
      loadingNext = false;

      _krList = result.values.toList();
      _krList.shuffle();
    });
  }

  // -----------------------------
  //     매칭 게임 로직
  // -----------------------------
  void _selectEn(String en) {
    if (matched.contains(en)) return;

    setState(() => selectedEn = en);

    if (selectedKr != null) _checkMatch();
  }

  void _selectKr(String kr) {
    final enMatched = words!.entries.firstWhere((e) => e.value == kr).key;

    if (matched.contains(enMatched)) return;

    setState(() => selectedKr = kr);

    if (selectedEn != null) _checkMatch();
  }

  void _checkMatch() {
    final correctKr = words![selectedEn];

    if (correctKr == selectedKr) {
      // 정답
      setState(() {
        matched.add(selectedEn!);
        selectedEn = null;
        selectedKr = null;
      });

      // 전부 맞추면 다음 랜덤 세트
      if (matched.length == words!.length && !loadingNext) {
        loadingNext = true;

        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          _fetchRandomWords();
        });
      }
    } else {
      // 오답 → 0.5초 후 선택 해제
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          selectedEn = null;
          selectedKr = null;
        });
      });
    }
  }

  // -----------------------------
  //     UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    if (words == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F0E9),
        body: Center(
          child: GifView.asset(
            'assets/images/background/mailbox_send.gif',
            width: 430,
            height: 430,
            frameRate: 12,
            autoPlay: true,
            loop: true,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final enList = words!.keys.toList();
    final krList = _krList;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              '단어 추출 중...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "맞춘 단어: ${matched.length} / ${words!.length}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 왼쪽 영어 리스트
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: enList.map((en) {
                        return _buildWordBox(
                          text: en,
                          selected: selectedEn == en,
                          matched: matched.contains(en),
                          onTap: () => _selectEn(en),
                        );
                      }).toList(),
                    ),

                    const SizedBox(width: 40),

                    // 오른쪽 한국어 리스트
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: krList.map((kr) {
                        final enKey =
                            words!.entries.firstWhere((e) => e.value == kr).key;

                        return _buildWordBox(
                          text: kr,
                          selected: selectedKr == kr,
                          matched: matched.contains(enKey),
                          onTap: () => _selectKr(kr),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordBox({
    required String text,
    required bool selected,
    required bool matched,
    required VoidCallback onTap,
  }) {
    Color bg = Colors.white;
    Color border = Colors.black;

    if (matched) {
      bg = Colors.green.shade300;
      border = Colors.green.shade900;
    } else if (selected) {
      bg = Colors.yellow.shade300;
      border = Colors.orange.shade700;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
