import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/status.dart' as status;

import '../config/url_config.dart';

/// Speed Game 전용 WebSocket 서비스
/// 서버(Spring Boot) 이벤트 규칙에 100% 맞춤
class GuessSocketService {
  WebSocketChannel? _channel;
  bool _closed = false;

  Function(Map<String, dynamic>)? onMessage;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  GuessSocketService();

  // ========================================
  // WebSocket 연결
  // ========================================
  void connect() {
    final wsUrl = UrlConfig.springBootSpeedWebSocketUrl;
    print('🔗 [Speed] WebSocket 연결 시도 → $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      print('✅ WebSocket 채널 생성 완료');

      _channel!.stream.listen(
        (message) {
          print('📩 [Speed] 서버 메시지 수신: $message');

          Map<String, dynamic> data;

          try {
            final decoded = jsonDecode(message);
            data = decoded is Map<String, dynamic>
                ? decoded
                : {'event': 'raw', 'data': decoded};
          } catch (e) {
            data = {'event': 'decode_error', 'raw': message.toString()};
          }

          if (!_controller.isClosed) {
            onMessage?.call(data);
            _controller.add(data);
          }
        },
        onDone: () => print('❌ WebSocket 연결 종료'),
        onError: (err) => print('⚠️ WebSocket 오류: $err'),
      );
    } catch (e) {
      print('🚨 WebSocket 예외: $e');
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_channel == null) return;
    final jsonString = jsonEncode(data);
    _channel!.sink.add(jsonString);
    print('📤 [SEND] $jsonString');
  }

  // ========================================
  // 클라이언트 → 서버 이벤트
  // ========================================

  /// 1) 매칭 요청
  /// 서버 이벤트: "match_request_speed"
  Future<void> requestMatch(String loginId, {bool manualStart = true}) async {
    _send({
      'event': 'match_request_speed',
      'loginId': loginId,
      'manualStart': manualStart,
    });
  }

  /// 2) 방 입장
  /// 서버 이벤트: "join_room_speed"
  void joinRoom(String roomId, String userId) {
    _send({
      'event': 'join_room_speed',
      'roomId': roomId,
      'userId': userId,
    });
  }

  /// 3) 게임 준비 완료
  /// 서버 이벤트: "game_ready"
  /// game_start_speed 수신 후 즉시 전송해야 함
  void sendGameReady(String roomId, {String? userId}) {
    _send({
      'event': 'game_ready',
      'roomId': roomId,
      if (userId != null) 'userId': userId,
    });
  }

  /// 4) 정답 제출
  /// 서버 이벤트: "submit_answer"
  void sendAnswer({
    required String roomId,
    required String loginId,
    required String word,
    required String wordKr,
  }) {
    _send({
      'event': 'submit_answer',
      'roomId': roomId,
      'loginId': loginId,
      'word': word,
      'wordKr': wordKr,
    });
  }

  /// 5) 게임 종료 요청
  /// 서버 이벤트: "game_over"
  void sendGameOver({
    required String roomId,
    required String loginId,
    int score = 0,
  }) {
    _send({
      'event': 'game_over',
      'roomId': roomId,
      'loginId': loginId,
      'score': score,
    });
  }

  /// 6) 매칭 취소 / 뒤로가기
  /// 서버 이벤트: "matching_exit"
  void sendMatchingExit({
    String? loginId,
    String? roomId,
    String? userId,
    String? reason,
  }) {
    _send({
      'event': 'matching_exit',
      if (loginId != null) 'loginId': loginId,
      if (roomId != null) 'roomId': roomId,
      if (userId != null) 'userId': userId,
      if (reason != null) 'reason': reason,
    });
  }

  // ========================================
  // 연결 종료
  // ========================================
  void disconnect() {
    if (_closed) return;
    _closed = true;

    try {
      if (_channel != null) {
        _channel!.sink
            .close(kIsWeb ? status.normalClosure : status.goingAway);
      }
    } catch (_) {}

    _channel = null;
  }

  void dispose() {
    if (!_controller.isClosed) _controller.close();
    disconnect();
  }
}
