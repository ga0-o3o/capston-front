import 'package:flutter/material.dart';
import 'word_api.dart';
import 'word_my_tab.dart';
import 'word_favorite_tab.dart';
import 'word_quiz_tab.dart';

class WordMenuPage extends StatefulWidget {
  final int wordbookId;

  const WordMenuPage({Key? key, required this.wordbookId}) : super(key: key);

  @override
  State<WordMenuPage> createState() => _WordMenuPageState();
}

class _WordMenuPageState extends State<WordMenuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              await WordApi.deleteWord(
                  widget.wordbookId, item.personalWordbookWordId);
            },
            onAdd: () {},
          ),
          WordFavoriteTab(
            wordbookId: widget.wordbookId,
          ),
        ],
      ),
    );
  }
}
