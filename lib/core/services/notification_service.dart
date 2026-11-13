import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Global navigator key for notification tap routing
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// ID of the room currently opened and viewed by the user.
  /// When this matches an incoming message's roomId, notifications are suppressed.
  static String? activeRoomId;

  /// Holds a pending room ID if a notification was tapped before the UI was ready.
  static String? pendingNavigationRoomId;

  /// Callback to execute when a notification is tapped.
  static void Function(String roomId)? onChatOpenedFromNotification;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _registeredUserId;

  /// De-duplication cache: tracks (roomId_body) to prevent duplicate
  /// notifications from WebSocket and FCM arriving at the same time.
  final Set<String> _recentNotificationKeys = {};

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'xchat_messages',
    'Chat Messages',
    description: 'Notifications for new 1:1 and group chat messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static void handleNotificationTap(String roomId) {
    if (activeRoomId == roomId) {
      debugPrint('ℹ️ [Notification] Already in room $roomId, ignoring tap');
      return;
    }

    if (onChatOpenedFromNotification != null) {
      onChatOpenedFromNotification!(roomId);
    } else {
      debugPrint(
        '⏳ [Notification] Queueing pending navigation to room: $roomId',
      );
      pendingNavigationRoomId = roomId;
    }
  }

  static void processPendingNavigation() {
    final pending = pendingNavigationRoomId;
    if (pending != null && onChatOpenedFromNotification != null) {
      pendingNavigationRoomId = null;
      debugPrint(
        '🚀 [Notification] Processing pending navigation to room: $pending',
      );
      onChatOpenedFromNotification!(pending);
    }
  }

  bool _shouldSuppressNotification(String roomId, String body) {
    // 1. Suppress if the user is currently viewing this exact chat room
    if (activeRoomId != null && activeRoomId == roomId) {
      debugPrint(
        '🔇 [Notification] Suppressed: user is currently viewing room: $roomId',
      );
      return true;
    }

    // 2. Suppress duplicate notifications arriving within 4 seconds (e.g. WS + FCM)
    final key = '${roomId}_$body';
    if (_recentNotificationKeys.contains(key)) {
      debugPrint(
        '🔇 [Notification] Suppressed duplicate notification for: $key',
      );
      return true;
    }

    _recentNotificationKeys.add(key);
    Timer(const Duration(seconds: 4), () {
      _recentNotificationKeys.remove(key);
    });

    return false;
  }

  Future<void> initialize({void Function(String roomId)? onChatTapped}) async {
    if (_initialized) return;
    if (onChatTapped != null) {
      onChatOpenedFromNotification = onChatTapped;
    }

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        '📱 [Push] Notification permission status: ${settings.authorizationStatus}',
      );

      // Configure Flutter Local Notifications for foreground heads-up banners
      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettingsDarwin = DarwinInitializationSettings();
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            handleNotificationTap(payload);
          }
        },
      );

      // Create high-importance Android notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      // Set foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen to foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      // Handle notification tapped when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final roomId = message.data['roomId'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          handleNotificationTap(roomId);
        }
      });

      // Check if app was launched from a terminated state via FCM notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final roomId = initialMessage.data['roomId'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          handleNotificationTap(roomId);
        }
      }

      // Check if launched from local notification tap when terminated
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          handleNotificationTap(payload);
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ [Push] NotificationService initialization notice: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final roomId = message.data['roomId'] as String? ?? '';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';

    // Check suppression (active room or duplicate)
    if (_shouldSuppressNotification(roomId, body)) {
      return;
    }

    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'New Message';

    _localNotifications.show(
      id: roomId.isNotEmpty ? roomId.hashCode : message.messageId.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: roomId,
    );
  }

  void showInstantMessageNotification({
    required int id,
    required String title,
    required String body,
    required String roomId,
  }) {
    if (kIsWeb) return;

    // Check suppression (active room or duplicate)
    if (_shouldSuppressNotification(roomId, body)) {
      return;
    }

    _localNotifications.show(
      id: roomId.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: roomId,
    );
  }

  Future<void> registerUserToken(String userId) async {
    _registeredUserId = userId;
    if (kIsWeb) return;

    try {
      if (!_initialized) {
        await initialize();
      }
      final messaging = FirebaseMessaging.instance;
      // ignore: deprecated_member_use
      final token = await messaging.getToken();

      if (token != null) {
        await _sendTokenToServer(userId, token);
      }

      // Keep token refreshed
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToServer(userId, newToken);
      });
    } catch (e) {
      debugPrint('⚠️ [Push] Error registering device push token: $e');
    }
  }

  Future<void> unregisterUserToken() async {
    if (_registeredUserId == null || kIsWeb) return;

    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final url = Uri.parse(
          '${ApiEndpoints.baseUrl}/api/xchat/users/push-token',
        );
        await http.delete(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': _registeredUserId, 'fcmToken': token}),
        );
      }
      _registeredUserId = null;
    } catch (_) {}
  }

  Future<void> _sendTokenToServer(String userId, String token) async {
    final platform = defaultTargetPlatform.name;

    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/xchat/users/push-token',
      );
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'fcmToken': token,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        debugPrint('✅ [Push] Device token registered with backend');
      }
    } catch (e) {
      debugPrint('⚠️ [Push] Failed to upload push token: $e');
    }
  }
}
