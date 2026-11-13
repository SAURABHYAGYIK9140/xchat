import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_endpoints.dart';

enum WsConnectionStatus {
  connecting,
  connected,
  disconnected,
  reconnecting,
}

class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._internal();
  factory WebSocketClient() => _instance;
  WebSocketClient._internal();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  String? _currentUserId;
  bool _intentionalClose = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  final _statusController = StreamController<WsConnectionStatus>.broadcast();
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;

  WsConnectionStatus _currentStatus = WsConnectionStatus.disconnected;
  WsConnectionStatus get currentStatus => _currentStatus;

  void connect({required String userId}) {
    _currentUserId = userId;
    _intentionalClose = false;
    _connectInternal();
  }

  void _updateStatus(WsConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void _connectInternal() {
    if (_intentionalClose) return;

    _updateStatus(_reconnectAttempts > 0 ? WsConnectionStatus.reconnecting : WsConnectionStatus.connecting);

    try {
      final uri = Uri.parse(ApiEndpoints.wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _handleIncoming(data);
        },
        onDone: () {
          debugPrint('🔌 WebSocket disconnected');
          _cleanUpConnection();
          _scheduleReconnect();
        },
        onError: (Object error) {
          debugPrint('❌ WebSocket error: $error');
          _cleanUpConnection();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // Successfully opened
      _reconnectAttempts = 0;
      _updateStatus(WsConnectionStatus.connected);

      // Authenticate socket session with current user
      if (_currentUserId != null) {
        send({
          'type': 'xchat_auth',
          'userId': _currentUserId,
        });
      }

      // Start ping heartbeat
      _startPingHeartbeat();
    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
      _cleanUpConnection();
      _scheduleReconnect();
    }
  }

  void _handleIncoming(dynamic raw) {
    try {
      final json = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'connection_established') {
        _updateStatus(WsConnectionStatus.connected);
        if (_currentUserId != null) {
          send({
            'type': 'xchat_auth',
            'userId': _currentUserId,
          });
        }
      } else if (type != 'pong') {
        _eventController.add(json);
      }
    } catch (e) {
      debugPrint('Error parsing incoming WS message: $e');
    }
  }

  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_currentStatus == WsConnectionStatus.connected) {
        send({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _scheduleReconnect() {
    if (_intentionalClose) return;
    _updateStatus(WsConnectionStatus.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 20);

    debugPrint('⏳ Scheduling WebSocket reconnect in ${delaySeconds}s (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _connectInternal();
    });
  }

  void _cleanUpConnection() {
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _updateStatus(WsConnectionStatus.disconnected);
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null && _currentStatus == WsConnectionStatus.connected) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint('Error sending WS message: $e');
      }
    }
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _cleanUpConnection();
  }
}
