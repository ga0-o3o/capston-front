import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:shared_preferences/shared_preferences.dart';

class BingoSocketService {
  final String baseUrl;
  WebSocketChannel? _channel;

  /// 외부(화면)에서 수신 이벤트를 받는 콜백
  Function(Map<String, dynamic>)? onMessage;

  BingoSocketService({required this.baseUrl});

  // ✅ WebSocket 연결
  void connect() {
    final wsUrl = baseUrl.replaceFirst('https://', 'wss://') + '/ws/match';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      print('🔗 WebSocket 연결 시도: $wsUrl');

      _channel!.stream.listen(
        (message) {
          print('📩 서버 메시지 수신: $message');
          final data = jsonDecode(message);
          onMessage?.call(data);
        },
        onDone: () => print('❌ 연결 종료됨 (onDone)'),
        onError: (error) => print('⚠️ 연결 오류 발생: $error'),
      );
    } catch (e) {
      print('🚨 예외 발생: $e');
    }
  }

  // ✅ 매칭 요청 (실제 로그인 ID 전송)
  Future<void> requestMatch(String loginId) async {
    if (_channel == null) {
      print('⚠️ WebSocket이 아직 연결되지 않음');
      return;
    }

    final payload = jsonEncode({
      'event': 'match_request',
      'loginId': loginId,
    });

    _channel!.sink.add(payload);
    print('📤 매칭 요청 보냄: $payload');
  }

  // ✅ 게임룸 참여
  void joinRoom(String roomId, String userId) {
    if (_channel == null) return;

    final payload = jsonEncode({
      'event': 'join_room',
      'roomId': roomId,
      'userId': userId,
    });

    _channel!.sink.add(payload);
    print('📤 join_room 전송: $payload');
  }

  // ✅ 빙고판 준비 완료
  void sendBoardReady(String roomId) {
    if (_channel == null) return;

    final payload = jsonEncode({
      'event': 'board_ready',
      'roomId': roomId,
    });

    _channel!.sink.add(payload);
    print('📤 board_ready 전송: $payload');
  }

  // ✅ 빙고 클릭 이벤트
  void sendNumberClick(String roomId, int number) {
    if (_channel == null) return;

    final payload = jsonEncode({
      'event': 'number_click',
      'roomId': roomId,
      'number': number,
    });

    _channel!.sink.add(payload);
    print('🟢 클릭 전송: $payload');
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
    print('🔌 WebSocket 연결 종료');
  }
}
