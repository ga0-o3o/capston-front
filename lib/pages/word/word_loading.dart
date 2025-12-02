import 'dart:async';
import 'package:flutter/material.dart';
import 'word_api.dart';

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

  bool loadingNext = false; // 새 문제 로딩 중인지 체크

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchRandomWords();

    // 로딩 작업 실행
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.task();
      } finally {
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  Future<void> _fetchRandomWords() async {
    final result = await WordApi.fetchRandomWords();
    if (!mounted) return;

    setState(() {
      words = result;
      selectedEn = null;
      selectedKr = null;
      matched.clear();
      loadingNext = false;
    });
  }

  void _selectEn(String en) {
    if (matched.contains(en)) return;
    setState(() => selectedEn = en);

    if (selectedKr != null) _checkMatch();
  }

  void _selectKr(String kr) {
    if (matched.contains(words!.entries.firstWhere((e) => e.value == kr).key)) {
      return;
    }

    setState(() => selectedKr = kr);

    if (selectedEn != null) _checkMatch();
  }

  void _checkMatch() {
    final correctKr = words![selectedEn];

    if (correctKr == selectedKr) {
      // 정답 처리
      setState(() {
        matched.add(selectedEn!);
        selectedEn = null;
        selectedKr = null;
      });

      // 🔥 모든 문제 맞췄으면 다음 문제 로딩
      if (matched.length == words!.length && !loadingNext) {
        loadingNext = true;

        Future.delayed(const Duration(milliseconds: 600), () {
          _fetchRandomWords();
        });
      }
    } else {
      // 오답 처리
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          selectedEn = null;
          selectedKr = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (words == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final enList = words!.keys.toList();
    final krList = words!.values.toList()..shuffle();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              '로딩 중... 단어 매칭 게임!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "맞춘 단어: ${matched.length} / ${words!.length}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 왼쪽 영어
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: enList.map((en) {
                      final isMatched = matched.contains(en);
                      final isSelected = selectedEn == en;

                      return _buildWordBox(
                        text: en,
                        selected: isSelected,
                        matched: isMatched,
                        onTap: () => _selectEn(en),
                      );
                    }).toList(),
                  ),

                  const SizedBox(width: 40),

                  // 오른쪽 한국어
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: krList.map((kr) {
                      final enMatched =
                          words!.entries.firstWhere((e) => e.value == kr).key;

                      final isMatched = matched.contains(enMatched);
                      final isSelected = selectedKr == kr;

                      return _buildWordBox(
                        text: kr,
                        selected: isSelected,
                        matched: isMatched,
                        onTap: () => _selectKr(kr),
                      );
                    }).toList(),
                  ),
                ],
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
