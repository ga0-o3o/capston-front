import 'dart:convert';
import 'package:flutter/material.dart';
import '../game/bingo_socket_service.dart';

class BingoGamePage extends StatefulWidget {
  final String roomId;
  final String userId;
  final BingoSocketService socket;

  const BingoGamePage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.socket,
  });

  @override
  State<BingoGamePage> createState() => _BingoGamePageState();
}

class _BingoGamePageState extends State<BingoGamePage> {
  List<String> availableWords = [];
  List<List<String?>> bingoBoard =
      List.generate(5, (_) => List.filled(5, null));

  @override
  void initState() {
    super.initState();

    // ✅ join_room 전송
    widget.socket.joinRoom(widget.roomId, widget.userId);

    // ✅ 서버 이벤트 수신
    widget.socket.onMessage = (msg) {
      final event = msg['event'];
      if (event == 'all_words') {
        setState(() {
          availableWords = List<String>.from(msg['data']);
        });
      } else if (event == 'game_begin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎯 모든 인원 준비 완료! 게임 시작!')),
        );
      }
    };
  }

  bool get _isBoardFilled {
    for (var row in bingoBoard) {
      if (row.contains(null)) return false;
    }
    return true;
  }

  void _checkBoardReady() {
    if (_isBoardFilled) {
      widget.socket.sendBoardReady(widget.roomId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('빙고판 준비 완료!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('빙고 (${widget.roomId.substring(0, 6)})')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            flex: 2,
            child: GridView.builder(
              itemCount: 25,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5),
              itemBuilder: (context, index) {
                int r = index ~/ 5;
                int c = index % 5;
                return DragTarget<String>(
                  onAccept: (word) {
                    setState(() {
                      bingoBoard[r][c] = word;
                      availableWords.remove(word);
                    });
                    _checkBoardReady();
                  },
                  builder: (context, candidate, rejected) => Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent),
                      color: bingoBoard[r][c] != null
                          ? Colors.blue.shade100
                          : Colors.white,
                    ),
                    child: Center(
                      child: Text(
                        bingoBoard[r][c] ?? '',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableWords.map((w) {
                  return Draggable<String>(
                    data: w,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.yellow,
                        child: Text(
                          w,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _wordChip(w),
                    ),
                    child: _wordChip(w),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wordChip(String w) => Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(w),
      );
}
