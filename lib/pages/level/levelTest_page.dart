// lib/pages/level/level_api.dart 의 API 사용
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// level_api import
import 'level_api.dart';

class LevelTestPage extends StatefulWidget {
  const LevelTestPage({super.key});

  @override
  State<LevelTestPage> createState() => _LevelTestPageState();
}

class _LevelTestPageState extends State<LevelTestPage> {
  // -----------------------------------------------------------
  // State Variables
  // -----------------------------------------------------------
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  int _serverDialogNum = 0;
  String _userRank = "Beginner";

  bool _isLoading = false;
  bool _isSending = false;

  // -----------------------------------------------------------
  // init & dispose
  // -----------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // Load Messages (server → local fallback)
  // -----------------------------------------------------------
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _serverDialogNum = prefs.getInt('server_dialog_num') ?? 0;
      _userRank = prefs.getString('user_rank') ?? 'Beginner';

      // ⭐ 서버에서 10개 로드
      await _loadMessagesFromServer();

      print('[LOAD] Loaded ${_messages.length} messages');
    } catch (e) {
      print('[ERROR] Failed to load messages: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // -----------------------------------------------------------
  // ⭐⭐⭐ 서버에서 최근 10개 대화 받아오기 (최종 리팩토링본)
  // -----------------------------------------------------------
  Future<void> _loadMessagesFromServer() async {
    try {
      print('[SERVER_LOAD] Fetching logs from API...');

      // GET /api/test/logs → 항상 10개 반환
      final logs = await LevelTestApi.getRecentLogs();

      if (!mounted) return;

      setState(() {
        _messages.clear();

        for (var log in logs) {
          final createdAt = DateTime.tryParse(
                log['created_at'] ?? DateTime.now().toIso8601String(),
              ) ??
              DateTime.now();

          // 유저 메시지
          if ((log['user_question'] ?? '').toString().trim().isNotEmpty) {
            _messages.add(
              ChatMessage(
                text: log['user_question'],
                isUser: true,
                timestamp: createdAt,
              ),
            );
          }

          // AI 메시지
          if ((log['ai_response'] ?? '').toString().trim().isNotEmpty) {
            _messages.add(
              ChatMessage(
                text: log['ai_response'],
                isUser: false,
                timestamp: createdAt,
              ),
            );
          }

          // dialog_num 업데이트
          _serverDialogNum = log['dialog_num'] ?? _serverDialogNum;
        }
      });

      await _saveMessages();
      print('[SERVER_LOAD] ✅ Loaded ${_messages.length} messages');
    } catch (e) {
      print('[SERVER_LOAD] ⚠️ Failed to fetch logs: $e');
      await _loadMessagesFromLocal();
    }
  }

  // -----------------------------------------------------------
  // Local fallback
  // -----------------------------------------------------------
  Future<void> _loadMessagesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMessagesJson = prefs.getString('level_test_messages');

      if (savedMessagesJson != null) {
        final List<dynamic> decoded = jsonDecode(savedMessagesJson);
        if (!mounted) return;
        setState(() {
          _messages.clear();
          _messages
              .addAll(decoded.map((m) => ChatMessage.fromJson(m)).toList());
        });
        print('[LOCAL_LOAD] Loaded ${_messages.length} messages');
      }
    } catch (e) {
      print('[LOCAL_LOAD] Failed to load local: $e');
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson =
          jsonEncode(_messages.map((m) => m.toJson()).toList());

      await prefs.setString('level_test_messages', messagesJson);
      await prefs.setInt('server_dialog_num', _serverDialogNum);
      await prefs.setString('user_rank', _userRank);

      print('[SAVE] Saved ${_messages.length} messages');
    } catch (e) {
      print('[SAVE] ERROR: $e');
    }
  }

  // -----------------------------------------------------------
  // Send Message
  // -----------------------------------------------------------
  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;

    final userText = _controller.text.trim();
    _controller.clear();

    if (_serverDialogNum >= 100) {
      _showCompletionDialog();
      return;
    }

    final userMessage = ChatMessage(
      text: userText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    if (!mounted) return;

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await _callLevelTestAPI(userText);

      final aiMessage = ChatMessage(
        text: response.message,
        isUser: false,
        timestamp: DateTime.now(),
        levelDisplay: response.levelDisplay,
      );

      if (mounted) {
        final previousRank = _userRank;

        setState(() {
          _messages.add(aiMessage);
          _serverDialogNum = response.dialogNum;
          _userRank = response.currentLevel;
          _isSending = false;
        });

        if (response.levelChanged && response.evaluatedLevel.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Level Updated: $previousRank → ${response.evaluatedLevel}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4E6E99),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      await _saveMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
      print('[ERROR] Send message failed: $e');
    }
  }

  // -----------------------------------------------------------
  // Call Level Test API
  // -----------------------------------------------------------
  Future<LevelTestResponse> _callLevelTestAPI(String message) async {
    try {
      final response = await LevelTestApi.sendAnswer(message);
      return LevelTestResponse(
        message: response.llmReply,
        dialogNum: response.dialogNum,
        currentLevel: response.currentLevel,
        levelChanged: response.levelChanged,
        evaluatedLevel: response.evaluatedLevel,
        levelDisplay: response.levelDisplay,
      );
    } catch (e) {
      print('[LEVEL_TEST] API failed: $e');
      rethrow;
    }
  }

  // -----------------------------------------------------------
  // UI Helpers
  // -----------------------------------------------------------
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (mounted) _scrollToBottom();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Level Test Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text('You have completed all 100 turns!'),
            const SizedBox(height: 8),
            Text(
              'Your Final Level: $_userRank',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _restartTest();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Start New Test'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Return to Home'),
          ),
        ],
      ),
    );
  }

  Future<void> _restartTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('level_test_messages');
    await prefs.remove('server_dialog_num');
    await prefs.remove('user_rank');

    if (!mounted) return;

    setState(() {
      _messages.clear();
      _serverDialogNum = 0;
      _userRank = 'Beginner';
    });

    print('[RESTART] Test restarted');
  }

  // -----------------------------------------------------------
  // Build UI
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F0E9),
      body: Column(
        children: [
          _buildHeader(),
          _buildTopInfo(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------
  // Widgets
  // -----------------------------------------------------------

  Widget _buildTopInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Wrap(
        spacing: 10,
        children: [
          const Icon(Icons.stars, color: Colors.amber),
          Text('Level: $_userRank'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Dialog $_serverDialogNum/100'),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3D4C63),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Stack(
            children: [
              Center(
                child: Text(
                  'LevelTest',
                  style:
                      GoogleFonts.pacifico(fontSize: 30, color: Colors.white),
                ),
              ),
              Positioned(
                right: 6,
                top: 15,
                child: IconButton(
                  icon: const Icon(Icons.restart_alt, color: Colors.white),
                  onPressed: _showRestartConfirmDialog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRestartConfirmDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restart Test?'),
        content: const Text('Delete all progress and start over?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _restartTest();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Start a conversation to begin your level test!',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 80, // 키보드 공간 확보
      ),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
    );
  }

  Widget _buildMessageBubble(ChatMessage m) {
    if (m.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4E6E99),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(m.text, style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Image.asset('assets/images/hanbok.png',
              width: 40, height: 40, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.text),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Your Level: $_userRank',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4E6E99),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isSending,
                decoration: InputDecoration(
                  hintText: '영어로 메시지를 입력하세요...',
                  filled: true,
                  fillColor: const Color(0xFFF6F0E9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4E6E99),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Data Classes
// -----------------------------------------------------------

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? levelDisplay;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.levelDisplay,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'levelDisplay': levelDisplay,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      levelDisplay: json['levelDisplay'],
    );
  }
}

class LevelTestResponse {
  final String message;
  final int dialogNum;
  final String currentLevel;
  final bool levelChanged;
  final String evaluatedLevel;
  final String levelDisplay;

  LevelTestResponse({
    required this.message,
    required this.dialogNum,
    required this.currentLevel,
    required this.levelChanged,
    required this.evaluatedLevel,
    required this.levelDisplay,
  });
}
