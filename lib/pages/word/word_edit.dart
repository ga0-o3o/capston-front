import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_api.dart';
import 'word_meaning.dart';
import '../fake_progress_bar.dart';

class WordEditPage extends StatefulWidget {
  final int wordbookId;
  final WordItem wordItem;

  const WordEditPage({
    Key? key,
    required this.wordbookId,
    required this.wordItem,
  }) : super(key: key);

  @override
  State<WordEditPage> createState() => _WordEditPageState();
}

class _WordEditPageState extends State<WordEditPage> {
  List<WordMeaning> _meanings = []; // WordMeaning 객체로 변경
  Set<int> _selectedMeaningIds = {}; // 선택된 id 저장
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMeanings();
  }

  Future<void> _loadMeanings() async {
    setState(() => _loading = true);

    // 서버에서 의미 가져오기
    final meanings = await WordApi.fetchWordMeanings(widget.wordItem.word);

    setState(() {
      _meanings = meanings;
      _selectedMeaningIds = {}; // 처음에는 선택 없음
      _loading = false;
    });
  }

  Future<void> _saveWord() async {
    if (_selectedMeaningIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('적어도 하나의 뜻을 선택하세요.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final success = await WordApi.updateWordGroup(
        widget.wordbookId,
        widget.wordItem.word,
        _selectedMeaningIds.toList(), // id 리스트를 서버에 전송
      );

      setState(() => _loading = false);

      if (success) {
        final updatedWord = widget.wordItem.copyWith(
          wordKr: _meanings
              .where((m) => _selectedMeaningIds.contains(m.wordId))
              .map((m) => m.wordKr)
              .toList(),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(true);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 수정되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어 수정에 실패했습니다.')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Stack(
        children: [
          // --- 배경 ---
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/edit_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Text(
                    '${widget.wordItem.word} 수정',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '뜻 선택',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _meanings.map((m) {
                          final selected =
                              _selectedMeaningIds.contains(m.wordId);
                          return ChoiceChip(
                            label: Text(m.wordKr),
                            selected: selected,
                            selectedColor: const Color(0xFF4E6E99),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                            ),
                            side: const BorderSide(color: Colors.black),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedMeaningIds.add(m.wordId);
                                } else {
                                  _selectedMeaningIds.remove(m.wordId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFCC8C8),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const Text('나가기'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _saveWord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // --- FakeProgressBar 오버레이 ---
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Align(
                alignment: Alignment(-0.6, 0), // 중앙보다 왼쪽으로 이동
                child: FakeProgressBar(
                  width: 250,
                  height: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
