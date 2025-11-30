import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:english_study/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatingPage extends StatefulWidget {
  const ChatingPage({Key? key}) : super(key: key);

  @override
  State<ChatingPage> createState() => _ChatingPageState();
}

// ✨ 추가: 메시지 구분을 위한 클래스
class ChatMessage {
  final String text;
  final bool isUser; // true: 사용자, false: AI
  final String? audioBase64; // 팟캐스트 오디오 데이터

  ChatMessage({
    required this.text,
    required this.isUser,
    this.audioBase64,
  });

  // 팟캐스트 메시지인지 확인
  bool get isPodcast => audioBase64 != null && audioBase64!.isNotEmpty;

  // JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'audioBase64': audioBase64,
    };
  }

  // JSON에서 불러오기 (복원용)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      audioBase64: json['audioBase64'] as String?,
    );
  }
}

class _ChatingPageState extends State<ChatingPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false; // ✨ 추가: 로딩 상태
  bool _isPodcastGenerating = false; // 팟캐스트 생성 중 여부
  final AudioPlayer _audioPlayer = AudioPlayer(); // 오디오 플레이어

  static const String _chatStorageKey = 'chat_messages';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();

    // ✅ 추가: API 호출 전 토큰 로드 확인
    try {
      // ✅ 토큰이 로드되었는지 먼저 확인
      final tokenLoaded = await ApiService.ensureTokenLoaded();
      if (!tokenLoaded) {
        throw Exception('로그인이 필요합니다. 토큰을 찾을 수 없습니다.');
      }

      final chatResponse = await ApiService.sendChatMessage(
        message: text,
        initialChat: _messages.length == 1, // 첫 메시지 여부
      );

      setState(() {
        _messages.add(ChatMessage(
          text: chatResponse.text,
          isUser: false,
          audioBase64: chatResponse.audioBase64,
        ));
        _isLoading = false;
      });

      // 자동 저장
      _saveMessages();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: '오류: ${e.toString()}', isUser: false));
        _isLoading = false;
      });
    }
  }

  // 오디오 재생 함수
  Future<void> _playAudio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      await _audioPlayer.stop(); // 🔹 이전 재생 중지
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오디오 재생 실패: $e')),
      );
    }
  }

  // 오디오 일시 정지 함수
  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop(); // 재생 중지(위치 0으로)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오디오 정지 실패: $e')),
      );
    }
  }

  // 팟캐스트 생성 함수
  void _generatePodcast() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대화 내용이 없습니다.')),
      );
      return;
    }

    // 최근 10개 메시지를 요약
    final recentMessages = _messages.take(10).map((msg) {
      return '${msg.isUser ? "User" : "AI"}: ${msg.text}';
    }).join('\n');

    setState(() {
      _isPodcastGenerating = true;
    });

    try {
      // ✅ 토큰이 로드되었는지 먼저 확인
      final tokenLoaded = await ApiService.ensureTokenLoaded();
      if (!tokenLoaded) {
        throw Exception('로그인이 필요합니다. 토큰을 찾을 수 없습니다.');
      }

      final podcastResponse = await ApiService.generatePodcastFromConversation(
        conversationHistory: recentMessages,
      );

      setState(() {
        _messages.add(ChatMessage(
          text: '📻 주제: ${podcastResponse.topic}\n\n${podcastResponse.script}',
          isUser: false,
          audioBase64: podcastResponse.audioBase64,
        ));
        _isPodcastGenerating = false;
      });

      // 자동 저장
      _saveMessages();

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팟캐스트가 생성되었습니다!')),
      );
    } catch (e) {
      setState(() {
        _isPodcastGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('팟캐스트 생성 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    // ✅ 서버에서 최근 10개 대화 로드 시도
    try {
      await _loadMessagesFromServer();
    } catch (e) {
      debugPrint('[CHAT_LOAD] ⚠️ 서버 로드 실패, 로컬 캐시 시도: $e');
      // 서버 실패 시 로컬 캐시 로드
      await _loadMessagesFromLocal();
    }
  }

  // ✅ 서버에서 최근 10개 대화 로드
  Future<void> _loadMessagesFromServer() async {
    try {
      final logs = await ApiService.getChatLogs();

      if (logs.isEmpty) {
        debugPrint('[CHAT_LOAD] ℹ️ 이전 대화 없음');
        return;
      }

      setState(() {
        _messages.clear();
        for (var log in logs) {
          // 사용자 메시지 추가
          _messages.add(ChatMessage(
            text: log['userChat'] ?? '',
            isUser: true,
          ));

          // AI 응답 추가
          _messages.add(ChatMessage(
            text: log['aiChat'] ?? '',
            isUser: false,
          ));
        }
      });

      // SharedPreferences에도 저장
      await _saveMessages();

      debugPrint('[CHAT_LOAD] ✅ 서버에서 ${logs.length}개 대화 로드');
    } catch (e) {
      debugPrint('[CHAT_LOAD] ❌ 서버 로드 실패: $e');
      rethrow;
    }
  }

  // 로컬 캐시에서 로드 (폴백)
  Future<void> _loadMessagesFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_chatStorageKey);

    if (jsonString == null) {
      debugPrint('[CHAT_LOAD] ℹ️ 로컬 캐시 없음');
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final loaded = decoded
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _messages.clear();
        _messages.addAll(loaded);
      });

      debugPrint('[CHAT_LOAD] ✅ 로컬에서 ${loaded.length}개 메시지 로드');
    } catch (e) {
      debugPrint('[CHAT_LOAD] ❌ 로컬 로드 실패: $e');
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString(_chatStorageKey, jsonString);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF3D4C63), // 네이비 배경
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            const DrawerHeader(
              child: Text(
                '채팅 목록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 왼쪽 다시하기 아이콘
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _messages.clear();
                      });
                    },
                  ),

                  // 중앙 필기체 글씨
                  Expanded(
                    child: Center(
                      child: Text(
                        'HiLight',
                        style: GoogleFonts.pacifico(
                          fontSize: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // 팟캐스트 생성 버튼
                  IconButton(
                    icon: _isPodcastGenerating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.podcasts,
                            color: Colors.white, size: 28),
                    onPressed: _isPodcastGenerating ? null : _generatePodcast,
                    tooltip: '대화 내용으로 팟캐스트 생성',
                  ),

                  // 오른쪽 햄버거 아이콘
                  Builder(
                    builder: (context) => IconButton(
                      icon:
                          const Icon(Icons.menu, color: Colors.white, size: 30),
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 흰색 볼록 영역
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: screenHeight * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEDEC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // 메시지 리스트
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ListView.builder(
                        reverse: true, // 새로운 메시지가 아래가 아닌 위로
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message =
                              _messages[_messages.length - 1 - index];

                          // ✨ 수정: 사용자/AI 구분
                          return Align(
                            alignment: message.isUser
                                ? Alignment.centerRight // 사용자: 오른쪽
                                : Alignment.centerLeft, // AI: 왼쪽
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10),
                              decoration: BoxDecoration(
                                color: message.isUser
                                    ? const Color(0xFF4E6E99) // 사용자: 파란색
                                    : message.isPodcast
                                        ? const Color(
                                            0xFFFFE5B4) // 팟캐스트: 연한 오렌지
                                        : Colors.grey.shade300, // AI: 회색
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 팟캐스트 표시
                                  if (message.isPodcast)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.podcasts,
                                              size: 16,
                                              color: Colors.orange.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Podcast',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // 텍스트
                                  Text(
                                    message.text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: message.isUser
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  // 재생 버튼 (팟캐스트인 경우)
                                  if (message.isPodcast)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 재생 버튼
                                          ElevatedButton.icon(
                                            onPressed: () => _playAudio(
                                                message.audioBase64!),
                                            icon: const Icon(Icons.play_arrow,
                                                size: 18),
                                            label: const Text('재생'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange.shade600,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // 정지 버튼
                                          OutlinedButton.icon(
                                            onPressed: _stopAudio,
                                            icon: const Icon(Icons.stop,
                                                size: 18),
                                            label: const Text('정지'),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color:
                                                      Colors.orange.shade600),
                                              foregroundColor:
                                                  Colors.orange.shade700,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ✨ 추가: 로딩 인디케이터
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          SizedBox(width: 10),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('AI가 답변 중...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                  // 입력창
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 140,
                            ),
                            child: TextField(
                              controller: _messageController,
                              enabled: !_isLoading,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              minLines: 1, // 한 줄에서 시작
                              maxLines: 5, // 최대 5줄까지 자동 확장 → 이후 내부 스크롤
                              decoration: InputDecoration(
                                hintText: '메시지를 입력하세요...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              _isLoading ? null : _sendMessage, // ✨ 로딩 중엔 비활성화
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6E99),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
