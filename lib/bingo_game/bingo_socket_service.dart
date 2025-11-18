import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/status.dart' as status;

// ✅ 중앙 URL 관리 import
import '../config/url_config.dart';

class BingoSocketService {
  WebSocketChannel? _channel;
  bool _closed = false;

  /// (레거시 호환) 단일 콜백 — 가능하면 쓰지 말고 messages 스트림을 구독하세요.
  Function(Map<String, dynamic>)? onMessage;

  /// ✅ 여러 위젯이 동시에 구독 가능한 브로드캐스트 스트림
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  BingoSocketService(); // ✅ 생성자에서 baseUrl 제거

  // ✅ WebSocket 연결
  void connect() {
    // ✅ UrlConfig에서 WebSocket URL 자동으로 가져옴
    final wsUrl = UrlConfig.springBootWebSocketUrl;
    print('🔗 WebSocket 연결 시도: $wsUrl');
    print('🌐 현재 환경 정보:');
    UrlConfig.printCurrentEnvironment();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      print('✅ WebSocket 채널 생성 완료');

      _channel!.stream.listen(
        (message) {
          print('📩 서버 메시지 수신: $message');
          Map<String, dynamic>? data;
          try {
            final decoded = jsonDecode(message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              data = {'event': 'raw', 'data': decoded};
            }
          } catch (e) {
            print('⚠️ jsonDecode 실패: $e');
            data = {'event': 'decode_error', 'raw': message.toString()};
          }

          if (data != null) {
            // 1) 레거시 단일 콜백 호출(있다면)
            onMessage?.call(data);
            // 2) ✅ 브로드캐스트로 모든 구독자에게 전달
            if (!_controller.isClosed) _controller.add(data);
          }
        },
        onDone: () => print('❌ 연결 종료됨 (onDone)'),
        onError: (error) => print('⚠️ 연결 오류 발생: $error'),
        cancelOnError: false,
      );
    } catch (e) {
      print('🚨 예외 발생: $e');
    }
  }

  // ✅ 안전 전송 헬퍼
  void _send(Map<String, dynamic> payload) {
    final json = jsonEncode(payload);
    _channel?.sink.add(json);
    print('📤 전송: $json');
  }

  // ====== API ======
  Future<void> requestMatch(String loginId, {bool manualStart = false}) async {
    if (_channel == null) {
      print('⚠️ WebSocket이 아직 연결되지 않음');
      return;
    }
    _send({
      'event': 'match_request',
      'loginId': loginId,
      'manualStart': manualStart,
    });
  }

  void forceStartMatch() {
    if (_channel == null) return;
    _send({'event': 'force_match'});
  }

  void joinRoom(String roomId, String userId) {
    if (_channel == null) return;
    _send({'event': 'join_room', 'roomId': roomId, 'userId': userId});
  }

  void sendBoardReady(String roomId, {String? userId}) {
    if (_channel == null) return;
    _send({
      'event': 'board_ready',
      'roomId': roomId,
      if (userId != null) 'userId': userId,
    });
  }

  void sendBack(
      {String? loginId, String? roomId, String? userId, String? reason}) {
    if (_channel == null) {
      print('⚠️ sendBack: 채널 미연결');
      return;
    }
    _send({
      'event': 'send_back',
      if (loginId != null && loginId.isNotEmpty) 'loginId': loginId,
      if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  void sendUserWordEvent({
    required String roomId,
    required String loginId,
    required String event, // 'word_click' | 'word_hilight' 등
    required String word,
    String? wordKr,
    bool wasHighlighted = false,
  }) {
    _send({
      'event': event, // ⚠️ 백엔드 이벤트명과 정확히 일치해야 함 ('word_hilight')
      'roomId': roomId,
      'loginId': loginId,
      'word': word,
      if (wordKr != null) 'wordKr': wordKr,
      if (wasHighlighted) 'wasHighlighted': true,
    });
  }

  void sendMarkWord(String roomId, String word) {
    if (_channel == null) return;
    _send({'event': 'mark_word', 'roomId': roomId, 'word': word});
  }

  void sendTurnDone(String roomId, String userId) {
    if (_channel == null) return;
    _send({'event': 'turn_done', 'roomId': roomId, 'userId': userId});
  }

  // ====== 종료/정리 ======
  void disconnect() {
    if (_closed) {
      print('⚠️ 이미 소켓 종료됨. 중복 disconnect 무시');
      return;
    }
    _closed = true;
    try {
      if (_channel != null) {
        if (kIsWeb) {
          _channel!.sink.close(status.normalClosure);
        } else {
          _channel!.sink.close(status.goingAway);
        }
        print('🔌 WebSocket 연결 종료 요청 전송');
      }
    } catch (e) {
      print('⚠️ disconnect 중 오류: $e');
    } finally {
      _channel = null;
      // 스트림은 보통 앱 생명주기 끝에서 닫음. 여기선 닫지 않음.
      // 필요시 별도 dispose 추가.
    }
  }

  /// 앱 종료 등에서 명시적으로 완전 정리하고 싶다면 호출
  void dispose() {
    try {
      if (!_controller.isClosed) _controller.close();
    } catch (_) {}
    disconnect();
  }
}
