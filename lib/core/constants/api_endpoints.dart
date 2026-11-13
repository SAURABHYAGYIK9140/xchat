import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Remote production backend running live on Render
  static const String remoteHttpBase = 'https://backend-7bx7.onrender.com';
  static const String remoteWsBase = 'wss://backend-7bx7.onrender.com/ws';

  // Local backend
  static const String localHttpBase = 'http://localhost:8000';
  static const String localWsBase = 'ws://localhost:8000/ws';

  // Android emulator local alias
  static const String androidEmulatorHttpBase = 'http://10.0.2.2:8000';
  static const String androidEmulatorWsBase = 'ws://10.0.2.2:8000/ws';

  // Current active mode (true = cloud Render, false = local server)
  // When running locally in debug, local server (which is already running on port 8000) provides instantaneous responses!
  static bool useLiveBackend = false;

  static String get localBase => kIsWeb
      ? localHttpBase
      : (defaultTargetPlatform == TargetPlatform.android ? androidEmulatorHttpBase : localHttpBase);

  static String get localWs => kIsWeb
      ? localWsBase
      : (defaultTargetPlatform == TargetPlatform.android ? androidEmulatorWsBase : localWsBase);

  static String get baseUrl => useLiveBackend ? remoteHttpBase : localBase;
  static String get wsUrl => useLiveBackend ? remoteWsBase : localWs;

  static String get login => '$baseUrl/api/xchat/auth/login';
  static String get users => '$baseUrl/api/xchat/users';
  static String get rooms => '$baseUrl/api/xchat/rooms';
  static String get directRoom => '$baseUrl/api/xchat/rooms/direct';
  static String get groupRoom => '$baseUrl/api/xchat/rooms/group';

  static String roomDetails(String roomId) => '$baseUrl/api/xchat/rooms/$roomId';
  static String roomMessages(String roomId) => '$baseUrl/api/xchat/rooms/$roomId/messages';
  static String sendMessage(String roomId) => '$baseUrl/api/xchat/rooms/$roomId/messages';
  static String markRoomRead(String roomId) => '$baseUrl/api/xchat/rooms/$roomId/read';
  static String addMember(String roomId) => '$baseUrl/api/xchat/rooms/$roomId/members';
  static String removeMember(String roomId, String userId) => '$baseUrl/api/xchat/rooms/$roomId/members/$userId';
}
