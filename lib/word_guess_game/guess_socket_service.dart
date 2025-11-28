import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/status.dart' as status;

// ✅ 중앙 URL 관리 import
import '../config/url_config.dart';

class GuessSocketService {
  WebSocketChannel? _channel;
  bool _closed = false;

  /// (레거시 호환) 단일 콜백 — 가능하면 쓰지 말고 messages 스트림을 구독하세요.
  Function(Map<String, dynamic>)? onMessage;

  /// ✅ 여러 위젯이 동시에 구독 가능한 브로드캐스트 스트림
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  GuessSocketService();

  // ✅ WebSocket 연결
  void connect() {
    // ✅ Speed Game 전용 ngrok WebSocket URL 사용 (/ws/speed)
    final wsUrl = UrlConfig.springBootSpeedWebSocketUrl;
    print('🔗 [Speed] WebSocket 연결 시도 → $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      print('✅ [Speed] WebSocket 채널 생성 완료 (ngrok 연결 성공)');

      _channel!.stream.listen(
        (message) {
          print('📩 [Speed] 서버 메시지 수신: $message');

          Map<String, dynamic>? data;
          try {
            final decoded = jsonDecode(message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              data = {'event': 'raw', 'data': decoded};
            }
          } catch (e) {
            print('⚠️ [Speed] jsonDecode 실패 → $e');
            data = {'event': 'decode_error', 'raw': message.toString()};
          }

          if (data != null) {
            onMessage?.call(data);
            if (!_controller.isClosed) {
              _controller.add(data);
            }
          }
        },
        onDone: () {
          print('❌ [Speed] WebSocket 연결 종료됨');
        },
        onError: (error) {
          print('⚠️ [Speed] WebSocket 오류 발생: $error');
          print('⚠️ [Speed] 현재 WebSocket URL = $wsUrl');
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('🚨 [Speed] WebSocket 예외 발생: $e');
      print('🚨 [Speed] 현재 WebSocket URL = $wsUrl');
    }
  }

  // ✅ 안전 전송 헬퍼
  void _send(Map<String, dynamic> payload) {
    final json = jsonEncode(payload);
    _channel?.sink.add(json);
    print('📤 [Speed] 전송: $json');
  }

  // ====== API ======

  /// 매칭 요청 (Speed Game 전용)
  Future<void> requestMatch(String loginId, {bool manualStart = true}) async {
    if (_channel == null) {
      print('⚠️ [Speed] WebSocket이 아직 연결되지 않음');
      return;
    }
    _send({
      'event': 'match_request_speed',
      'loginId': loginId,
      'manualStart': manualStart,
    });
  }

  /// 방 참가 (단어 불러오기)
  void joinRoom(String roomId, String userId) {
    if (_channel == null) return;
    _send({
      'event': 'join_room_speed',
      'roomId': roomId,
      'userId': userId,
    });
  }

  /// 보드 준비 완료
  void sendBoardReady(String roomId, {String? userId}) {
    if (_channel == null) return;
    _send({
      'event': 'board_ready_speed',
      'roomId': roomId,
      if (userId != null) 'userId': userId,
    });
  }

  /// 나가기/매칭 취소
  void sendBack({
    String? loginId,
    String? roomId,
    String? userId,
    String? reason,
  }) {
    if (_channel == null) {
      print('⚠️ [Speed] sendBack: 채널 미연결');
      return;
    }
    _send({
      'event': 'send_back_speed',
      if (loginId != null && loginId.isNotEmpty) 'loginId': loginId,
      if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  /// 답안 제출
  void sendAnswer({
    required String roomId,
    required String loginId,
    required String word,
    required String answer,
  }) {
    if (_channel == null) return;
    _send({
      'event': 'speed_answer',
      'roomId': roomId,
      'loginId': loginId,
      'word': word,
      'answer': answer,
    });
  }

  /// 게임 종료 (승리 선언)
  void sendWin({
    required String roomId,
    required String loginId,
    int score = 0,
  }) {
    if (_channel == null) return;
    _send({
      'event': 'speed_win',
      'roomId': roomId,
      'loginId': loginId,
      'score': score,
    });
  }

  /// 새 문제 단어 요청
  void requestNewQuestion(String roomId) {
    if (_channel == null) return;
    _send({
      'event': 'speed_new_question',
      'roomId': roomId,
    });
  }

  // ====== 종료/정리 ======
  void disconnect() {
    if (_closed) {
      print('⚠️ [Speed] 이미 소켓 종료됨. 중복 disconnect 무시');
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
        print('🔌 [Speed] WebSocket 연결 종료 요청 전송');
      }
    } catch (e) {
      print('⚠️ [Speed] disconnect 중 오류: $e');
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
