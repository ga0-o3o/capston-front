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

// 합쳐진 카드 구조
class QuizCard {
  final String word;
  final List<String> meanings;
  final Map<String, WordItem> meaningToOriginal; // 뜻 → 실제 WordItem 매핑

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

  @override
  void initState() {
    super.initState();

    // 같은 단어(word)끼리 묶어서 뜻(wordKr)을 합치고 매핑 생성
    final Map<String, Map<String, WordItem>> wordMap = {};
    for (var w in widget.words) {
      if (!wordMap.containsKey(w.word)) {
        wordMap[w.word] = {};
      }
      for (var kr in w.wordKr) {
        wordMap[w.word]![kr] = w;
      }
    }

    // QuizCard 생성
    _items = wordMap.entries.map((e) {
      final meanings = e.value.keys.toList();
      return QuizCard(
        word: e.key,
        meanings: meanings,
        meaningToOriginal: e.value,
      );
    }).toList();

    _nextQuiz();
  }

  void _nextQuiz() {
    if (_items.isEmpty) return;
    _cur = _items[_rnd.nextInt(_items.length)];
    _meanCtrl.clear();
    _compCtrl.clear();
    setState(() {});
    Future.delayed(
        const Duration(milliseconds: 30), () => _meanFocus.requestFocus());
  }

  bool _isMeaningCorrect() {
    if (_cur == null) return false;
    final input = _meanCtrl.text.trim();
    if (input.isEmpty) return false;
    return _cur!.meanings.contains(input);
  }

  List<Issue> _validateComposition(String sentence, String word) {
    if (!sentence.contains(word)) {
      return [Issue(sentence, "단어를 포함해야 합니다: $word")];
    }
    return [];
  }

  Future<void> _confirmQuiz() async {
    final mean = _meanCtrl.text.trim();
    if (mean.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('뜻을 먼저 입력하세요.')));
      return;
    }
    if (_cur == null) return;

    final isCorrect = _isMeaningCorrect();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect ? '정답! 🎉' : '오답 😅  정답: ${_cur!.meanings}',
        ),
      ),
    );

    // 서버 기록
    WordItem recordItem = isCorrect
        ? _cur!.meaningToOriginal[mean]!
        : _cur!.meaningToOriginal.values.first;

    await WordApi.recordQuiz(
      personalWordbookId: recordItem.personalWordbookId,
      wordId: recordItem.personalWordbookWordId,
      isWrong: isCorrect ? true : false,
    );

    // 영작 체크
    final comp = _compCtrl.text.trim();
    if (comp.isNotEmpty) {
      // 단어 포함 체크
      if (!comp.contains(_cur!.word)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('작문에 반드시 단어 "${_cur!.word}"를 포함해야 합니다.')),
        );
        return;
      }

      // 4단어 이상 체크
      if (comp.split(RegExp(r'\s+')).length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('작문은 최소 4단어 이상이어야 합니다.')),
        );
        return;
      }

      // 문법 체크
      final issues = _validateComposition(comp, _cur!.word);
      final grammarIssues = await WordApi.checkGrammar(comp);
      final allIssues = [...issues, ...grammarIssues];

      if (allIssues.isNotEmpty) {
        // 문법 오류 모달
        await showModalBottomSheet(
          context: context,
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
                const Text(
                  '문법 오류가 있습니다.',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.black),
                ),
                const SizedBox(height: 8),
                ...allIssues.map((d) => Text(
                      "틀린 부분: '${d.wrongText}' → ${d.message}",
                      style: const TextStyle(color: Colors.black),
                    )),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _nextQuiz(); // ← 닫기 눌렀을 때 다음 문제
                    },
                    child: const Text(
                      '닫기',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return; // 모달 뜨면 여기서 return
      }
    }

    // 영작 없거나 문법 오류 없으면 바로 다음 문제
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Center(
            child: Text(_cur!.word,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 56, fontWeight: FontWeight.w800)),
          ),
        ),
        TextField(
          controller: _meanCtrl,
          focusNode: _meanFocus,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirmQuiz(),
          decoration: InputDecoration(
            labelText: '뜻(필수)',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _compCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '작문 (선택: 단어 포함, 4단어↑ 권장)',
            hintText: '예) I can easily use this word in a sentence.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E6E99),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _confirmQuiz,
            child: const Text('확인',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
