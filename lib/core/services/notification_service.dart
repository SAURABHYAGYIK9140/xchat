import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handled automatically by Google Play Services / Notification Center
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _registeredUserId;
  void Function(String roomId)? onChatOpenedFromNotification;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'xchat_messages',
    'Chat Messages',
    description: 'Notifications for new 1:1 and group chat messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize({void Function(String roomId)? onChatTapped}) async {
    if (_initialized) return;
    onChatOpenedFromNotification = onChatTapped;

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
          if (payload != null && onChatOpenedFromNotification != null) {
            onChatOpenedFromNotification!(payload);
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
        if (roomId != null && onChatOpenedFromNotification != null) {
          onChatOpenedFromNotification!(roomId);
        }
      });

      // Check if app was launched from a terminated state via a notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final roomId = initialMessage.data['roomId'] as String?;
        if (roomId != null && onChatOpenedFromNotification != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            onChatOpenedFromNotification!(roomId);
          });
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ [Push] NotificationService initialization notice: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final roomId = message.data['roomId'] as String?;

    if (notification != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title ?? 'New Message',
        body: notification.body,
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
  }

  Future<void> registerUserToken(String userId) async {
    _registeredUserId = userId;
    if (kIsWeb) return;

    try {
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
    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/xchat/users/push-token',
      );
      final platform = defaultTargetPlatform.name;

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'fcmToken': token,
          'platform': platform,
        }),
      );

      if (res.statusCode == 200) {
        debugPrint(
          '✅ [Push] Device token registered with backend for user: $userId',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [Push] Failed to upload push token: $e');
    }
  }
}

