import 'package:flutter_test/flutter_test.dart';
import 'package:xchat/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationService.activeRoomId = null;
    NotificationService.pendingNavigationRoomId = null;
    NotificationService.onChatOpenedFromNotification = null;
  });

  group('NotificationService Routing & Suppression Tests', () {
    test(
      'activeRoomId prevents notifications while inside the chat screen',
      () {
        NotificationService.activeRoomId = 'room_123';
        expect(NotificationService.activeRoomId, 'room_123');

        // Tapping notification for currently active room is safely ignored
        bool callbackInvoked = false;
        NotificationService.onChatOpenedFromNotification = (_) {
          callbackInvoked = true;
        };

        NotificationService.handleNotificationTap('room_123');
        expect(callbackInvoked, false);
      },
    );

    test(
      'handleNotificationTap redirects to room or queues pending navigation',
      () {
        String? openedRoomId;
        NotificationService.onChatOpenedFromNotification = (roomId) {
          openedRoomId = roomId;
        };

        NotificationService.handleNotificationTap('room_456');
        expect(openedRoomId, 'room_456');
      },
    );

    test(
      'pendingNavigationRoomId stores tapped room when UI callback is not yet set',
      () {
        NotificationService.onChatOpenedFromNotification = null;
        NotificationService.handleNotificationTap('room_789');

        expect(NotificationService.pendingNavigationRoomId, 'room_789');

        String? lateOpenedRoomId;
        NotificationService.onChatOpenedFromNotification = (roomId) {
          lateOpenedRoomId = roomId;
        };

        NotificationService.processPendingNavigation();
        expect(lateOpenedRoomId, 'room_789');
        expect(NotificationService.pendingNavigationRoomId, null);
      },
    );
  });
}
