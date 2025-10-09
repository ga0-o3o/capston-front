import 'package:flutter/material.dart';
import 'word_item.dart';
import 'word_api.dart';

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
  List<String> _meanings = []; // 서버에서 불러온 모든 뜻
  Set<String> _selectedMeanings = {}; // 선택된 뜻
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMeanings();
  }

  Future<void> _loadMeanings() async {
    setState(() => _loading = true);

    final meanings = await WordApi.fetchWordMeanings(widget.wordItem.word);

    // 서버에서 불러온 뜻 + 원래 뜻들을 모두 포함 (중복 제거)
    final allMeanings = {...meanings, ...widget.wordItem.wordKr}.toList();

    setState(() {
      _meanings = allMeanings;
      _selectedMeanings = widget.wordItem.wordKr.toSet(); // ✅ 기존 뜻 자동 체크
      _loading = false;
    });
  }

  Future<void> _saveWord() async {
    if (_selectedMeanings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('적어도 하나의 뜻을 선택하세요.')),
      );
      return;
    }

    setState(() => _loading = true);

    // ✅ selectedWordIds 대신 groupWordIds 사용
    final success = await WordApi.updateWordGroup(
      widget.wordbookId,
      widget.wordItem.groupWordIds,
    );

    setState(() => _loading = false);

    if (success) {
      widget.wordItem.wordKr = _selectedMeanings.toList();
      if (mounted) Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어가 수정되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어 수정에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 백버튼 방지
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F0E9),
        appBar: AppBar(
          title: Text('${widget.wordItem.word} 수정'),
          backgroundColor: const Color(0xFF4E6E99),
          automaticallyImplyLeading: false, // 뒤로가기 제거
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '뜻 선택',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _meanings.map((m) {
                            final selected = _selectedMeanings.contains(m);
                            return ChoiceChip(
                              label: Text(m),
                              selected: selected,
                              selectedColor: const Color(0xFF4E6E99),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                              ),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedMeanings.add(m);
                                  } else {
                                    _selectedMeanings.remove(m);
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
                                : () =>
                                    Navigator.of(context).pop(false), // ✅ 단순 종료
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
                  ],
                ),
        ),
      ),
    );
  }
}
