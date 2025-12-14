import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Completer<void>? _initializationCompleter;
  StreamSubscription<String>? _tokenRefreshSubscription;

  NotificationService(this._ref);

  Future<void> initialize() async {
    try {
      await _ensureFirebaseInitialized();
      await _registerToken();
    } catch (error) {
      print('Notification initialization failed: $error');
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (_isInitialized) {
      return _initializationCompleter?.future ?? Future.value();
    }

    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    _initializationCompleter = Completer<void>();

    try {
      await Firebase.initializeApp();
      print("Firebase Initialized");

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
        await _setupLocalNotifications();
        await _setupFCMListeners();
      } else {
        print('User declined or has not accepted permission');
      }

      _isInitialized = true;
      _initializationCompleter!.complete();
    } catch (e, stackTrace) {
      _initializationCompleter!.completeError(e, stackTrace);
      print("Error initializing notifications (likely missing google-services.json): $e");
    } finally {
      _initializationCompleter = null;
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap
        print("Notification tapped: ${response.payload}");
        // TODO: Navigate to chat
      },
    );
  }

  Future<void> _setupFCMListeners() async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // Navigate to chat
    });

    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      print('FCM token refreshed. Syncing with backend...');
      await _registerToken(forceToken: token);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _registerToken({String? forceToken}) async {
    if (!_hasAuthToken()) {
      print('Skipping push token registration: user is not authenticated yet.');
      return;
    }

    try {
      final token = forceToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print("FCM Token: $token");
        print("Attempting to send token to backend...");
        try {
          await _ref.read(dioProvider).post(
                '/notifications/token',
                data: {'token': token},
              );
          print("Token registered with backend successfully.");
        } catch (apiError) {
           print("Failed to register token with backend: $apiError");
           if (apiError is DioException) {
             print("API Error Response: ${apiError.response?.data}");
           }
        }
      } else {
        print("FCM Token is null");
      }
    } catch (e) {
      print("Error getting FCM token: $e");
    }
  }

  Future<void> unregisterToken() async {
    if (!_hasAuthToken()) {
      print('Skipping push token unregister: user is not authenticated.');
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        print('No FCM token available to unregister.');
        return;
      }

      await _ref.read(dioProvider).delete(
            '/notifications/token',
            data: {'token': token},
          );
      print('Token unregistered from backend.');
    } catch (error) {
      print('Failed to unregister push token: $error');
    }
  }

  bool _hasAuthToken() {
    final dio = _ref.read(dioProvider);
    final authHeader = dio.options.headers['Authorization'];
    return authHeader is String && authHeader.isNotEmpty;
  }

  // Public method to manually refresh token
  Future<void> refreshToken() async => _registerToken();
}
