import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for managing local OS-level notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
    print('NotificationService: Initialized successfully');
  }

  void _onNotificationTap(NotificationResponse response) {
    print('NotificationService: Notification tapped - ${response.payload}');
    // Can be used to navigate to specific screen based on payload
  }

  /// Show a notification for a new order
  Future<void> showNewOrderNotification({
    required String orderId,
    required String customerName,
    required double amount,
    String? shopName,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'new_orders',
          'New Orders',
          channelDescription: 'Notifications for new orders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/launcher_icon',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final String title = '🛍️ New Order!';
    final String body = shopName != null
        ? '$customerName ordered ₹${amount.toStringAsFixed(0)} from $shopName'
        : '$customerName ordered ₹${amount.toStringAsFixed(0)}';

    await _notifications.show(
      orderId.hashCode, // Unique ID based on order
      title,
      body,
      details,
      payload: orderId,
    );

    print('NotificationService: Showed notification for order $orderId');
  }

  /// Show a notification for order ready for delivery
  Future<void> showReadyForDeliveryNotification({
    required String orderId,
    required String customerName,
    required String address,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'delivery_orders',
          'Delivery Orders',
          channelDescription: 'Notifications for orders ready for delivery',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/launcher_icon',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications.show(
      orderId.hashCode,
      '🚚 Ready for Delivery!',
      'Order for $customerName is ready. Deliver to: $address',
      details,
      payload: orderId,
    );
  }

  /// Show a generic notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'general',
          'General Notifications',
          channelDescription: 'General app notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Request notification permissions (especially for iOS)
  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    return true;
  }
}
