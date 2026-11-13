class ApiEndpoints {
  // Live production backend (Render)
  static const String baseUrl = 'https://backend-7bx7.onrender.com';
  static const String wsUrl = 'wss://backend-7bx7.onrender.com/ws';

  static String get login => '$baseUrl/api/xchat/auth/login';
  static String get users => '$baseUrl/api/xchat/users';
  static String get rooms => '$baseUrl/api/xchat/rooms';
  static String get directRoom => '$baseUrl/api/xchat/rooms/direct';
  static String get groupRoom => '$baseUrl/api/xchat/rooms/group';

  static String roomDetails(String roomId) =>
      '$baseUrl/api/xchat/rooms/$roomId';
  static String roomMessages(String roomId) =>
      '$baseUrl/api/xchat/rooms/$roomId/messages';
  static String sendMessage(String roomId) =>
      '$baseUrl/api/xchat/rooms/$roomId/messages';
  static String markRoomRead(String roomId) =>
      '$baseUrl/api/xchat/rooms/$roomId/read';
  static String addMember(String roomId) =>
      '$baseUrl/api/xchat/rooms/$roomId/members';
  static String removeMember(String roomId, String userId) =>
      '$baseUrl/api/xchat/rooms/$roomId/members/$userId';
}
