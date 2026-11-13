import 'package:flutter_test/flutter_test.dart';
import 'package:xchat/data/models/message_model.dart';
import 'package:xchat/data/models/room_model.dart';
import 'package:xchat/data/models/user_model.dart';
import 'package:xchat/core/utils/date_formatter.dart';
import 'package:xchat/logic/rooms/rooms_state.dart';
import 'package:xchat/main.dart';

void main() {
  group('XChat Core Widget & Application Tests', () {
    testWidgets('XChatApp launches and renders cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(const XChatApp());
      await tester.pump();

      // Verify brand title is rendered
      expect(find.text('XChat'), findsWidgets);
    });
  });

  group('XChat Data Models Unit Tests', () {
    test('UserModel serializes and deserializes accurately', () {
      final now = DateTime.now();
      final user = UserModel(
        id: 'usr_test',
        username: 'johndoe',
        displayName: 'John Doe',
        avatarUrl: 'https://example.com/avatar.png',
        isOnline: true,
        lastSeen: now,
        createdAt: now,
      );

      final json = user.toJson();
      final fromJson = UserModel.fromJson(json);

      expect(fromJson.id, user.id);
      expect(fromJson.username, user.username);
      expect(fromJson.displayName, user.displayName);
      expect(fromJson.isOnline, true);
    });

    test('MessageModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final message = MessageModel(
        id: 'msg_1',
        roomId: 'room_1',
        senderId: 'usr_1',
        senderName: 'Alice',
        content: 'Hello XChat!',
        messageType: 'text',
        status: MessageDeliveryStatus.delivered,
        createdAt: now,
        updatedAt: now,
      );

      final json = message.toJson();
      final fromJson = MessageModel.fromJson(json);

      expect(fromJson.id, 'msg_1');
      expect(fromJson.content, 'Hello XChat!');
      expect(fromJson.status, MessageDeliveryStatus.delivered);
      expect(fromJson.senderName, 'Alice');
    });

    test('RoomModel parses 1:1 and Group conversations with unread counts', () {
      final roomJson = {
        'id': 'room_grp_1',
        'name': 'Core Engineers',
        'isGroup': true,
        'description': 'Dev chat',
        'avatarUrl': 'https://example.com/grp.png',
        'createdBy': 'usr_1',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastMessage': 'Welcome team!',
        'unreadCount': 3,
        'members': [
          {
            'id': 'mem_1',
            'roomId': 'room_grp_1',
            'userId': 'usr_1',
            'role': 'admin',
            'joinedAt': DateTime.now().toIso8601String(),
          },
        ],
      };

      final room = RoomModel.fromJson(roomJson);

      expect(room.id, 'room_grp_1');
      expect(room.isGroup, true);
      expect(room.name, 'Core Engineers');
      expect(room.unreadCount, 3);
      expect(room.members.length, 1);
      expect(room.members.first.role, 'admin');
    });
  });

  group('XChat Utilities & State Tests', () {
    test('DateFormatter formats time and date dividers accurately', () {
      final now = DateTime.now();
      final formattedTime = DateFormatter.formatMessageTime(now);
      expect(formattedTime.isNotEmpty, true);

      final divider = DateFormatter.formatDateDivider(now);
      expect(divider, 'Today');
    });

    test('RoomsState filters conversations by search query', () {
      final now = DateTime.now();
      final rooms = [
        RoomModel(
          id: '1',
          name: 'Mobile Engineering',
          isGroup: true,
          createdBy: 'u1',
          createdAt: now,
          updatedAt: now,
        ),
        RoomModel(
          id: '2',
          name: 'Alice Cooper',
          isGroup: false,
          createdBy: 'u2',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final state = RoomsLoaded(rooms: rooms, searchQuery: 'Mobile');
      expect(state.filteredRooms.length, 1);
      expect(state.filteredRooms.first.name, 'Mobile Engineering');

      final emptyState = RoomsLoaded(rooms: rooms, searchQuery: 'NonExistent');
      expect(emptyState.filteredRooms.isEmpty, true);
    });
  });
}
