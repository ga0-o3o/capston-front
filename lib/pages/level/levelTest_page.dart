import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ level_api.dart import 추가
import 'level_api.dart';

class LevelTestPage extends StatefulWidget {
  const LevelTestPage({super.key});

  @override
  State<LevelTestPage> createState() => _LevelTestPageState();
}

class _LevelTestPageState extends State<LevelTestPage> {
  // ==========================================================================
  // 상태 변수 (State Variables)
  // ==========================================================================
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  // ✅ 서버 dialog_num만 사용 (로컬 turn 증가 없음)
  int _serverDialogNum = 0; // 서버에서 받은 dialog_num만 저장
  String _userRank = "Beginner";

  bool _isLoading = false;
  bool _isSending = false;

  // ❌ 제거: 하드코딩된 baseUrl
  // FastAPI URL은 level_api.dart에서 ApiService.fastApiUrl을 사용합니다

  // ==========================================================================
  // 초기화 (Initialization)
  // ==========================================================================
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

  // ==========================================================================
  // 메시지 불러오기/저장 (Load/Save Messages)
  // ==========================================================================
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ 서버 dialog_num 불러오기
      final savedDialogNum = prefs.getInt('server_dialog_num') ?? 0;
      final savedUserRank = prefs.getString('user_rank') ?? 'Beginner';
      final savedMessagesJson = prefs.getString('level_test_messages');

      if (savedMessagesJson != null) {
        final List<dynamic> decoded = jsonDecode(savedMessagesJson);
        setState(() {
          _serverDialogNum = savedDialogNum;
          _userRank = savedUserRank;
          _messages.clear();
          _messages
              .addAll(decoded.map((m) => ChatMessage.fromJson(m)).toList());
        });

        print(
            '[LOAD] Loaded ${_messages.length} messages, Dialog Num: $_serverDialogNum, Level: $_userRank');
      } else {
        setState(() {
          _serverDialogNum = 0;
          _userRank = savedUserRank;
        });
        print('[LOAD] No saved messages');
      }
    } catch (e) {
      print('[ERROR] Failed to load messages: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson =
          jsonEncode(_messages.map((m) => m.toJson()).toList());

      // ✅ 서버 dialog_num 저장
      await prefs.setString('level_test_messages', messagesJson);
      await prefs.setInt('server_dialog_num', _serverDialogNum);
      await prefs.setString('current_level', _userRank);

      print(
          '[SAVE] Saved ${_messages.length} messages, Dialog Num: $_serverDialogNum, Level: $_userRank');
    } catch (e) {
      print('[ERROR] Failed to save messages: $e');
    }
  }

  // ==========================================================================
  // 메시지 전송 (Send Message)
  // ==========================================================================
  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;

    final userText = _controller.text.trim();
    _controller.clear();

    // ✅ 100턴 완료 체크 (서버 dialog_num 기준)
    if (_serverDialogNum >= 100) {
      _showCompletionDialog();
      return;
    }

    final userMessage = ChatMessage(
      text: userText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
      // ✅ 로컬 turn 증가 제거 - 서버에서만 관리
      // _currentTurn++; <- 삭제됨
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
        setState(() {
          _messages.add(aiMessage);
          // ✅ 서버의 dialog_num만 사용
          _serverDialogNum = response.dialogNum;
          _userRank = response.currentLevel;
          _isSending = false;
        });

        print(
            '[LEVEL TEST] Response received - Server Dialog Num ${response.dialogNum}/100');
      }

      await _saveMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
      }
      print('[ERROR] Send message failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${e.toString()}')),
        );
      }
    }
  }

  // ==========================================================================
  // Level Test API 호출 (Call Level Test API)
  // ==========================================================================
  Future<LevelTestResponse> _callLevelTestAPI(String message) async {
    // ✅ level_api.dart의 sendAnswer 메서드 사용
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
      print('[LEVEL_TEST] ❌ API call failed: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // UI 헬퍼 함수 (UI Helper Functions)
  // ==========================================================================
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
            Text(
              'You have completed all 100 turns!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your Final Level: $_userRank',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4E6E99),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _restartTest();
              if (mounted) {
                Navigator.pop(context);
              }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('level_test_messages');
      await prefs.remove('server_dialog_num');
      await prefs.remove('user_rank');

      setState(() {
        _messages.clear();
        _serverDialogNum = 0;
        _userRank = 'Beginner';
      });

      print('[RESTART] Test restarted');
    } catch (e) {
      print('[ERROR] Failed to restart test: $e');
    }
  }

  void _showRestartConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Level Test?'),
        content: const Text(
          'This will delete all current progress and start a new test.\n\nAre you sure?',
        ),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // UI 빌드 (Build UI)
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: Column(
        children: [
          _buildHeader(),
          // ========================================
          // 상단 정보 표시 (Top Info Display)
          // ========================================
          _buildTopInfo(),

          // ========================================
          // 채팅 메시지 영역 (Chat Messages Area)
          // ========================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),

          // ========================================
          // 입력 영역 (Input Area)
          // ========================================
          _buildInputArea(),
        ],
      ),
    );
  }

  // ==========================================================================
  // 위젯 빌더 (Widget Builders)
  // ==========================================================================

  /// 상단 정보 표시 (레벨, dialog_num)
  Widget _buildTopInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          const Icon(Icons.stars, color: Colors.amber, size: 24),
          Text(
            'Level: $_userRank',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E6E99),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Dialog $_serverDialogNum/100',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4E6E99),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 커스텀 헤더 (AppBar 대신)
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF3D4C63),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 70,
          child: Stack(
            children: [
              // ⭐ 중앙 LevelTest 텍스트
              Align(
                alignment: Alignment.center,
                child: Text(
                  'LevelTest',
                  style: GoogleFonts.pacifico(
                    fontSize: 30,
                    color: Colors.white,
                  ),
                ),
              ),

              // ⭐ 완전히 오른쪽 끝 아이콘
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6), // 더 끝으로 가게
                  child: SizedBox(
                    height: 40,
                    width: 40,
                    child: Center(
                      child: IconButton(
                        padding: EdgeInsets.zero, // 불필요한 내부 padding 제거
                        icon: const Icon(
                          Icons.restart_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: _showRestartConfirmDialog,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 메시지 목록
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation to begin\nyour level test!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  /// 메시지 말풍선
  Widget _buildMessageBubble(ChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF4E6E99),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // AI 메시지면 프로필 + 말풍선
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👤 프로필 사진
          ClipOval(
            child: Image.asset(
              'assets/images/hanbok/ai.png', // ← 네 이미지 경로에 맞게 수정
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),

          // 💬 말풍선
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),

                // 레벨 표시 있을 때만 추가
                if (message.levelDisplay != null &&
                    message.levelDisplay!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message.levelDisplay!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4E6E99),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 입력 영역
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  filled: true,
                  fillColor: const Color(0xFFF6F0E9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                enabled: !_isSending,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4E6E99),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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

// ==========================================================================
// 데이터 클래스 (Data Classes)
// ==========================================================================

/// 채팅 메시지
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

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'levelDisplay': levelDisplay,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      levelDisplay: json['levelDisplay'],
    );
  }
}

/// 레벨 테스트 API 응답
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

  factory LevelTestResponse.fromJson(Map<String, dynamic> json) {
    return LevelTestResponse(
      message: json['llm_reply'] ?? '',
      dialogNum: json['dialog_num'] ?? 0,
      currentLevel: json['current_level'] ?? 'Beginner',
      levelChanged: json['level_changed'] ?? false,
      evaluatedLevel: json['evaluated_level'] ?? '',
      levelDisplay: json['level_display'] ?? '',
    );
  }
}
