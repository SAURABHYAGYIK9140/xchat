import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  Future<List<RoomModel>> getUserRooms(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.rooms}?userId=$userId'),
      headers: {'x-user-id': userId},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawList = data['rooms'] as List<dynamic>;
      return rawList.map((r) => RoomModel.fromJson(r as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load conversations: ${response.body}');
    }
  }

  Future<RoomModel> getRoomDetails(String roomId, String userId) async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.roomDetails(roomId)}?userId=$userId'),
      headers: {'x-user-id': userId},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to get room details: ${response.body}');
    }
  }

  Future<RoomModel> getOrCreateDirectRoom(String userAId, String userBId) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.directRoom),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userAId': userAId,
        'userBId': userBId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create direct room: ${response.body}');
    }
  }

  Future<RoomModel> createGroupRoom({
    required String creatorId,
    required String name,
    String? description,
    String? avatarUrl,
    required List<String> memberUserIds,
  }) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.groupRoom),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'creatorId': creatorId,
        'name': name,
        'description': description,
        'avatarUrl': avatarUrl,
        'memberUserIds': memberUserIds,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  Future<RoomModel> addGroupMember(String roomId, String targetUserId) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.addMember(roomId)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'targetUserId': targetUserId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to add group member: ${response.body}');
    }
  }

  Future<RoomModel> removeGroupMember(String roomId, String targetUserId) async {
    final response = await http.delete(
      Uri.parse(ApiEndpoints.removeMember(roomId, targetUserId)),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to remove group member: ${response.body}');
    }
  }

  Future<List<MessageModel>> getRoomMessages(String roomId, {int limit = 50}) async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.roomMessages(roomId)}?limit=$limit'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawList = data['messages'] as List<dynamic>;
      return rawList.map((m) => MessageModel.fromJson(m as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load messages: ${response.body}');
    }
  }

  Future<MessageModel> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    String? clientTempId,
    String? replyToId,
    String messageType = 'text',
  }) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.sendMessage(roomId)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'senderId': senderId,
        'content': content,
        'clientTempId': clientTempId,
        'replyToId': replyToId,
        'messageType': messageType,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return MessageModel.fromJson(data['message'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  Future<void> markRoomAsRead(String roomId, String userId) async {
    await http.post(
      Uri.parse(ApiEndpoints.markRoomRead(roomId)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }
}

