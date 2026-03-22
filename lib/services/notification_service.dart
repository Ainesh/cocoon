/// Notification service for Kairos app.
///
/// Handles Firebase Cloud Messaging (FCM) setup, token management,
/// and local notification display. Works with Firestore to store
/// device tokens and sync notification preferences.
///
/// ## Usage
///
/// ```dart
/// final notificationService = NotificationService();
///
/// // Initialize on app start
/// await notificationService.initialize();
///
/// // Store token in Firestore
/// await notificationService.registerDeviceToken(userId);
/// ```
///
/// ## Platform Setup Required
///
/// ### iOS
/// 1. Enable Push Notifications capability in Xcode
/// 2. Enable Background Modes > Remote notifications
/// 3. Upload APNs key to Firebase Console
///
/// ### Android
/// Works automatically with google-services.json
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// =============================================================================
// Background Handler (must be top-level)
// =============================================================================

/// Handles background messages when app is terminated.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // Note: Don't do heavy work here. The system may kill the process.
  // For navigation on tap, use getInitialMessage() in the app.
}

// =============================================================================
// Notification Service
// =============================================================================

/// Service for handling push notifications via Firebase Cloud Messaging.
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  factory NotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  /// Stream controller for notification navigation events.
  final _navigationController =
      StreamController<NotificationNavigation>.broadcast();

  /// Pending navigation from app launch via notification (terminated state).
  NotificationNavigation? _pendingNavigation;

  /// Stream of navigation events triggered by notification taps.
  /// Listen to this in your shell/root widget to handle navigation.
  Stream<NotificationNavigation> get onNotificationTap =>
      _navigationController.stream;

  /// Consumes and returns any pending navigation from app launch.
  /// Returns null if there is no pending navigation.
  NotificationNavigation? consumePendingNavigation() {
    final pending = _pendingNavigation;
    _pendingNavigation = null;
    return pending;
  }

  /// Current FCM token for this device.
  String? get fcmToken => _fcmToken;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the notification service.
  ///
  /// Call this early in app startup (after Firebase.initializeApp()).
  /// Returns the FCM token if successful, null if permissions denied.
  Future<String?> initialize() async {
    if (_isInitialized) return _fcmToken;

    try {
      // Set up background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request permission (iOS will show prompt, Android auto-grants)
      final settings = await _requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permissions denied');
        return null;
      }

      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        // Note: Caller should re-register token with Firestore
      });

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      return _fcmToken;
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
      return null;
    }
  }

  /// Request notification permissions from the user.
  Future<NotificationSettings> _requestPermission() async {
    return await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false, // Requires special entitlement
    );
  }

  /// Initialize local notifications for foreground display.
  Future<void> _initializeLocalNotifications() async {
    // Skip local notifications on web - not supported
    if (kIsWeb) return;

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create Android notification channels for different priorities.
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // Default channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'default',
        'Default',
        description: 'Default notification channel',
        importance: Importance.defaultImportance,
      ),
    );

    // High priority channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'high',
        'Important',
        description: 'Important notifications',
        importance: Importance.high,
      ),
    );

    // Low priority channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'low',
        'Updates',
        description: 'Low priority updates',
        importance: Importance.low,
      ),
    );

    // Silent channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'silent',
        'Silent',
        description: 'Silent notifications',
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message Handlers
  // ---------------------------------------------------------------------------

  /// Set up handlers for incoming messages.
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When app is opened from a notification (background -> foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    _checkInitialMessage();
  }

  /// Handle messages received while app is in foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show as local notification (encode full data as JSON payload for tap handling)
    await _showLocalNotification(
      title: notification.title ?? 'Kairos',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
      channelId: _getChannelFromData(message.data),
    );
  }

  /// Handle notification tap when app was in background.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    _navigateFromNotification(message.data);
  }

  /// Check if app was opened from a notification when terminated.
  /// Stores as pending since the UI may not be ready yet.
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated via notification');
      final data = initialMessage.data;
      final spaceId = data['spaceId'] as String? ?? '';
      if (spaceId.isNotEmpty) {
        _pendingNavigation = NotificationNavigation(
          type: data['type'] as String? ?? '',
          spaceId: spaceId,
          entityType: data['entityType'] as String? ?? '',
          entityId: data['entityId'] as String? ?? '',
        );
      }
    }
  }

  /// Handle local notification tap.
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload == null || response.payload!.isEmpty) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromNotification(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  /// Navigate based on notification data.
  ///
  /// Stores as pending AND emits to stream to cover both cases:
  /// - Stream listener already active → handled immediately
  /// - Stream listener not yet set up (background resume timing) → consumed later
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final spaceId = data['spaceId'] as String?;
    final entityType = data['entityType'] as String?;
    final entityId = data['entityId'] as String?;

    debugPrint(
      'Navigate from notification: type=$type, spaceId=$spaceId, '
      'entityType=$entityType, entityId=$entityId',
    );

    if (spaceId == null || spaceId.isEmpty) return;

    final nav = NotificationNavigation(
      type: type ?? '',
      spaceId: spaceId,
      entityType: entityType ?? '',
      entityId: entityId ?? '',
    );

    // Store as pending for late listeners (background resume timing)
    _pendingNavigation = nav;

    // Also emit for any active listeners
    _navigationController.add(nav);
  }

  /// Get appropriate channel ID based on notification data.
  String _getChannelFromData(Map<String, dynamic> data) {
    final priority = data['priority'] as String? ?? 'normal';
    switch (priority) {
      case 'high':
      case 'critical':
        return 'high';
      case 'low':
        return 'low';
      case 'silent':
        return 'silent';
      default:
        return 'default';
    }
  }

  // ---------------------------------------------------------------------------
  // Local Notifications
  // ---------------------------------------------------------------------------

  /// Show a local notification (used for foreground messages).
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'default',
  }) async {
    // Local notifications not supported on web
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'high'
          ? 'Important'
          : channelId == 'low'
          ? 'Updates'
          : channelId == 'silent'
          ? 'Silent'
          : 'Default',
      importance: channelId == 'high'
          ? Importance.high
          : channelId == 'low'
          ? Importance.low
          : channelId == 'silent'
          ? Importance.min
          : Importance.defaultImportance,
      priority: channelId == 'high'
          ? Priority.high
          : channelId == 'low'
          ? Priority.low
          : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Token Management
  // ---------------------------------------------------------------------------

  /// Get device information for token storage.
  Map<String, dynamic> getDeviceInfo() {
    String platform;
    String device;

    if (kIsWeb) {
      platform = 'web';
      device = 'Web Browser';
    } else if (Platform.isIOS) {
      platform = 'ios';
      device = 'iOS Device';
    } else {
      platform = 'android';
      device = 'Android Device';
    }

    return {
      'platform': platform,
      'device': device,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Delete the current FCM token (e.g., on logout).
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _fcmToken = null;
    debugPrint('FCM token deleted');
  }

  // ---------------------------------------------------------------------------
  // Permission Status
  // ---------------------------------------------------------------------------

  /// Check current notification permission status.
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Check if notifications are currently authorized.
  Future<bool> isAuthorized() async {
    final status = await getPermissionStatus();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Request permission again (e.g., from settings).
  Future<bool> requestPermissionAgain() async {
    final settings = await _requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}

// =============================================================================
// Navigation Data
// =============================================================================

/// Data from a notification tap used to navigate to the right screen.
class NotificationNavigation {
  const NotificationNavigation({
    required this.type,
    required this.spaceId,
    this.entityType = '',
    this.entityId = '',
  });

  /// Activity type (e.g., 'checkin', 'moment_planned').
  final String type;

  /// The space this notification belongs to.
  final String spaceId;

  /// Entity type (e.g., 'moment', 'checkin').
  final String entityType;

  /// Entity ID for deep-linking to a specific item.
  final String entityId;

  /// Whether this is a moment-related notification.
  bool get isMoment => const [
    'moment_planned',
    'moment_edited',
    'moment_deleted',
    'moment_completed',
  ].contains(type);

  /// Whether this is a check-in notification.
  bool get isCheckIn => type == 'checkin';

  /// Whether this is a memory prompt notification.
  bool get isMemoryPrompt => type == 'memory_prompt';

  /// Whether this is a memory-created notification.
  bool get isMemoryCreated => type == 'memory_created';

  /// Whether this is a memory-reaction notification.
  bool get isMemoryReaction => type == 'memory_reaction';

  /// Whether this is any memory-related notification.
  bool get isMemory => type.startsWith('memory_');

  @override
  String toString() =>
      'NotificationNavigation(type: $type, spaceId: $spaceId, '
      'entityType: $entityType, entityId: $entityId)';
}
