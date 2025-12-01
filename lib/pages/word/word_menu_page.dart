import 'package:flutter/material.dart';
import 'word_api.dart';
import 'word_my_tab.dart';
import 'word_favorite_tab.dart';
import 'word_quiz_tab.dart';
import 'word_item.dart';

class WordMenuPage extends StatefulWidget {
  final int wordbookId;

  const WordMenuPage({Key? key, required this.wordbookId}) : super(key: key);

  @override
  State<WordMenuPage> createState() => _WordMenuPageState();
}

class _WordMenuPageState extends State<WordMenuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WordItem> _words = [];
  bool _isLoadingWords = false; // 🔒 중복 load 방지 플래그

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWords();
  }

  // 단어 불러오기
  Future<void> _loadWords() async {
    // 🔒 이미 load 중이면 중복 호출 방지
    if (_isLoadingWords) {
      print('⚠️ 이미 단어를 불러오는 중입니다. 중복 호출 무시.');
      return;
    }

    _isLoadingWords = true;
    try {
      final fetched = await WordApi.fetchWords(widget.wordbookId);
      if (mounted) {
        setState(() {
          _words = fetched;
        });
      }
    } finally {
      _isLoadingWords = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 키보드가 나타날 때 화면 자동 조정
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D4C63),
        title: const Text(
          '단어장',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '내 단어'),
            Tab(text: '즐겨찾기'),
            Tab(text: '퀴즈'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          WordMyTab(
            wordbookId: widget.wordbookId,
            onDelete: (item) async {
              // 자식이 자체적으로 단어를 새로고침하므로 여기서는 퀴즈 탭용 데이터만 갱신
              await _loadWords();
            },
            onAdd: () async {
              // 자식이 자체적으로 단어를 새로고침하므로 여기서는 퀴즈 탭용 데이터만 갱신
              await _loadWords();
            },
          ),
          WordFavoriteTab(
            wordbookId: widget.wordbookId,
          ),
          WordQuizTab(
            words: _words,
          ),
        ],
      ),
    );
  }
}
