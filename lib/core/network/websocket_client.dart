import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_endpoints.dart';

enum WsConnectionStatus { connecting, connected, disconnected, reconnecting }

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
  int _activeCandidateIndex = 0;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  final _statusController = StreamController<WsConnectionStatus>.broadcast();
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;

  WsConnectionStatus _currentStatus = WsConnectionStatus.disconnected;
  WsConnectionStatus get currentStatus => _currentStatus;

  List<String> get _candidateWsUrls {
    return [ApiEndpoints.wsUrl];
  }

  void connect({required String userId}) {
    _currentUserId = userId;
    _intentionalClose = false;
    _activeCandidateIndex = 0;
    _cleanUpConnection();
    _connectInternal();
  }

  void _updateStatus(WsConnectionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  void _connectInternal() {
    if (_intentionalClose) return;

    _updateStatus(
      _reconnectAttempts > 0
          ? WsConnectionStatus.reconnecting
          : WsConnectionStatus.connecting,
    );

    final candidates = _candidateWsUrls;
    final selectedUrl = candidates[_activeCandidateIndex % candidates.length];
    debugPrint(
      '🔌 [WS] Connecting to $selectedUrl (attempt $_reconnectAttempts)...',
    );

    try {
      final uri = Uri.parse(selectedUrl);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _handleIncoming(data);
        },
        onDone: () {
          debugPrint('🔌 [WS] Stream closed from server');
          _cleanUpConnection();
          _scheduleReconnect();
        },
        onError: (Object error) {
          debugPrint('❌ [WS] Stream error: $error');
          _cleanUpConnection();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('❌ [WS] Connection initiation failed: $e');
      _cleanUpConnection();
      _scheduleReconnect();
    }
  }

  void _handleIncoming(dynamic raw) {
    try {
      final json = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'connection_established') {
        debugPrint('🟢 [WS] Connection established successfully');
        _reconnectAttempts = 0;
        _updateStatus(WsConnectionStatus.connected);
        _startPingHeartbeat();

        // Authenticate user presence immediately upon socket handshake
        if (_currentUserId != null) {
          send({'type': 'xchat_auth', 'userId': _currentUserId});
        }
      } else if (type == 'xchat_auth_success') {
        debugPrint('👤 [WS] Authenticated as $_currentUserId');
        _eventController.add(json);
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
        send({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  void _scheduleReconnect() {
    if (_intentionalClose) return;
    _updateStatus(WsConnectionStatus.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Alternate to fallback URL if primary fails after 2 attempts
    if (_reconnectAttempts % 2 == 0) {
      _activeCandidateIndex++;
    }

    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 10);
    debugPrint(
      '⏳ [WS] Reconnecting in ${delaySeconds}s (attempt $_reconnectAttempts)...',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _connectInternal();
    });
  }

  void _cleanUpConnection() {
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
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
    _cleanUpConnection();
  }
}
