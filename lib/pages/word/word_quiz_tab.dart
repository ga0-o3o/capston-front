import 'dart:math';
import 'package:flutter/material.dart';
import 'word_api.dart';
import 'word_item.dart';

class WordQuizTab extends StatefulWidget {
  final List<WordItem> words;

  const WordQuizTab({super.key, required this.words});

  @override
  State<WordQuizTab> createState() => _WordQuizTabState();
}

class QuizCard {
  final String word;
  final List<String> meanings; // UI 표시용
  final Map<String, WordItem> meaningToOriginal; // 뜻 → WordItem 매핑

  QuizCard({
    required this.word,
    required this.meanings,
    required this.meaningToOriginal,
  });
}

class _WordQuizTabState extends State<WordQuizTab> {
  final _meanCtrl = TextEditingController();
  final _compCtrl = TextEditingController();
  final _meanFocus = FocusNode();

  late List<QuizCard> _items;
  QuizCard? _cur;
  final _rnd = Random();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    // 단어별 그룹핑
    final Map<String, Map<String, WordItem>> wordMap = {};
    for (var w in widget.words) {
      if (!wordMap.containsKey(w.word)) wordMap[w.word] = {};
      for (var kr in w.wordKrOriginal) {
        wordMap[w.word]![kr] = w;
      }
    }

    _items = wordMap.entries.map((e) {
      final uiMeanings =
          e.value.values.expand((w) => w.wordKr).toSet().toList();
      return QuizCard(
        word: e.key,
        meanings: uiMeanings,
        meaningToOriginal: e.value,
      );
    }).toList();

    _nextQuiz();
  }

  String _norm(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  void _nextQuiz() {
    if (_items.isEmpty) return;
    _cur = _items[_rnd.nextInt(_items.length)];
    _meanCtrl.clear();
    _compCtrl.clear();
    setState(() {});
    Future.delayed(
        const Duration(milliseconds: 30), () => _meanFocus.requestFocus());
  }

  Future<void> _submitAnswer() async {
    if (_cur == null || _submitting) return;

    final mean = _meanCtrl.text.trim();
    if (mean.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('뜻을 입력하세요.')));
      return;
    }

    setState(() => _submitting = true);

    final comp = _compCtrl.text.trim();

    // -----------------------------
    // 1) 서버로부터 정답 뜻 리스트 가져오기
    // -----------------------------
    final serverMeanings = await WordApi.checkQuiz(_cur!.word);

    final normInput = _norm(mean);
    final correctNormalized = serverMeanings.map((m) => _norm(m)).toList();

    final bool isCorrect = correctNormalized.contains(normInput);

    // -----------------------------
    // 2) personalWordbookId / wordId 찾기
    // -----------------------------
    final WordItem recordItem =
        _cur!.meaningToOriginal.values.first; // 아무 WordItem이나 대표로 사용

    final personalWordbookId = recordItem.personalWordbookId;
    final wordId = recordItem.personalWordbookWordId;

    // -----------------------------
    // 3) 기록 저장
    // -----------------------------
    await WordApi.recordQuiz(
      personalWordbookId: personalWordbookId,
      wordId: wordId,
      isWrong: !isCorrect,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    // -----------------------------
    // 4) 정답/오답 표시
    // -----------------------------
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect ? '정답! 🎉' : '오답 😅 정답: ${serverMeanings.join(', ')}',
        ),
      ),
    );

    // -----------------------------
    // 5) 문법 검사 (선택)
    // -----------------------------
    if (comp.isNotEmpty) {
      final grammarIssues = await WordApi.checkGrammar(comp);

      if (grammarIssues.isNotEmpty) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          builder: (_) => Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('문법 오류가 있습니다.',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 8),
                ...grammarIssues.map((d) => Text(
                      "틀린 부분: '${d.wrongText}' → ${d.message}",
                      style: const TextStyle(color: Colors.black),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _nextQuiz();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E6E99),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child:
                        const Text('닫기', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    }

    _nextQuiz();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty || _cur == null) {
      return const Center(
        child: Text('단어가 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
      );
    }

<<<<<<< HEAD
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Text(
                _cur!.word,
                style:
                    const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
=======
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24, // 키보드 높이 고려
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: Center(
                child: Text(
                  _cur!.word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 56, fontWeight: FontWeight.w800),
                ),
>>>>>>> 6f5da5361a234f979c0b8e48c7f9f652ab8ebd2a
              ),
            ),
            TextField(
            controller: _meanCtrl,
            focusNode: _meanFocus,
            decoration: InputDecoration(
              labelText: '뜻(필수)',
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _compCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '작문 (선택)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _submitAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6E99),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('확인',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
