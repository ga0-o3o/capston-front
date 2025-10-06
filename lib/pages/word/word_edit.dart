// lib/pages/word/word_edit.dart
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
  List<String> _meanings = []; // 서버에서 가져온 뜻
  Set<String> _selectedMeanings = {}; // 선택한 뜻
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMeanings();
  }

  Future<void> _loadMeanings() async {
    setState(() => _loading = true);
    final meanings = await WordApi.fetchWordMeanings(widget.wordItem.word);

    setState(() {
      _meanings = meanings;
      // 원래 단어의 뜻만 선택
      _selectedMeanings =
          meanings.where((m) => widget.wordItem.wordKr.contains(m)).toSet();
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

    final success = await WordApi.updateWordGroup(
      widget.wordbookId,
      widget.wordItem.personalWordbookWordId,
      _selectedMeanings.toList(), // 선택한 뜻 보내기
    );

    setState(() => _loading = false);

    if (success) {
      widget.wordItem.wordKr = _selectedMeanings.toList();
      Navigator.of(context).pop(true); // 저장 성공 후 닫기
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
    // Dialog 내에서 다른 영역을 눌러도 닫히지 않도록 GestureDetector 사용
    return WillPopScope(
      onWillPop: () async => false, // 백버튼도 막음
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F0E9),
        appBar: AppBar(
          title: Text('${widget.wordItem.word} 수정'),
          backgroundColor: const Color(0xFF4E6E99),
          automaticallyImplyLeading: false, // 기본 뒤로가기 제거
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
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFCC8C8), // 배경색
                              foregroundColor: Colors.white, // 글자색
                              minimumSize: const Size(100, 40), // 버튼 최소 크기
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(0), // 모서리 각지게
                                side: const BorderSide(
                                    color: Colors.black, width: 2), // 테두리
                              ),
                            ),
                            child: const Text(
                              '나가기',
                              style: TextStyle(color: Color(0xFF4E6E99)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _saveWord,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4E6E99), // 배경색
                              foregroundColor: Colors.white, // 글자색
                              minimumSize: const Size(100, 40), // 버튼 최소 크기
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(0), // 모서리 각지게
                                side: const BorderSide(
                                    color: Colors.black, width: 2), // 테두리
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
