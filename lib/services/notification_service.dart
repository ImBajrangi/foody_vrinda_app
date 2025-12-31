import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:foody_vrinda/models/user_model.dart';
import 'package:foody_vrinda/config/notification_sound_config.dart';

/// Service for managing local OS-level notifications with custom sounds
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

  /// Get Android notification details with custom sound for role
  Future<AndroidNotificationDetails> _getAndroidDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    UserRole? role,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) async {
    // Get sound file name from config
    String? soundFileName;
    if (role != null) {
      final soundFile = await NotificationSoundConfig.getSoundForRole(role);
      if (soundFile != 'default') {
        // Remove .wav extension for Android resource name
        soundFileName = soundFile.replaceAll('.wav', '').replaceAll('-', '_');
      }
    }

    // Create unique channel ID based on sound to allow different sounds
    // (Android 8+ locks sound to channel after creation)
    final effectiveChannelId = soundFileName != null
        ? '${NotificationSoundConfig.getChannelId(channelId, role)}_$soundFileName'
        : NotificationSoundConfig.getChannelId(channelId, role);

    return AndroidNotificationDetails(
      effectiveChannelId,
      NotificationSoundConfig.getChannelName(channelName, role),
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      playSound: true,
      sound: soundFileName != null
          ? RawResourceAndroidNotificationSound(soundFileName)
          : null, // null = use default system sound
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
    );
  }

  /// Get iOS notification details with custom sound for role
  Future<DarwinNotificationDetails> _getIOSDetails({UserRole? role}) async {
    // Get sound file name from config (async) - prefixed with _ for future use
    final _ = role != null
        ? await NotificationSoundConfig.getSoundForRole(role)
        : null;

    // For iOS, sound file should be in .caf format and placed in the bundle
    // If no custom sound, iOS will use default
    // For now, using default iOS sounds

    return const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // sound: sound, // Would require sound files in iOS bundle
    );
  }

  /// Show a notification for a new order with role-based sound
  Future<void> showNewOrderNotification({
    required String orderId,
    required String customerName,
    required double amount,
    String? shopName,
    UserRole? userRole, // Role of the user receiving the notification
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = await _getAndroidDetails(
      channelId: 'new_orders',
      channelName: 'New Orders',
      channelDescription: 'Notifications for new orders',
      role: userRole,
    );

    final iosDetails = await _getIOSDetails(role: userRole);

    final NotificationDetails details = NotificationDetails(
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

    print(
      'NotificationService: Showed notification for order $orderId (Role: ${userRole?.value ?? "default"})',
    );
  }

  /// Show a notification for order ready for delivery with role-based sound
  Future<void> showReadyForDeliveryNotification({
    required String orderId,
    required String customerName,
    required String address,
    UserRole? userRole, // Role of the user receiving the notification
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = await _getAndroidDetails(
      channelId: 'delivery_orders',
      channelName: 'Delivery Orders',
      channelDescription: 'Notifications for orders ready for delivery',
      role: userRole,
    );

    final iosDetails = await _getIOSDetails(role: userRole);

    final NotificationDetails details = NotificationDetails(
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

    print(
      'NotificationService: Showed delivery notification for order $orderId (Role: ${userRole?.value ?? "default"})',
    );
  }

  /// Show order status update notification with role-based sound
  Future<void> showOrderStatusNotification({
    required String orderId,
    required String status,
    required String message,
    UserRole? userRole,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = await _getAndroidDetails(
      channelId: 'order_updates',
      channelName: 'Order Updates',
      channelDescription: 'Notifications for order status updates',
      role: userRole,
    );

    final iosDetails = await _getIOSDetails(role: userRole);

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    String emoji = '📦';
    switch (status.toLowerCase()) {
      case 'confirmed':
        emoji = '✅';
        break;
      case 'preparing':
        emoji = '👨‍🍳';
        break;
      case 'ready':
        emoji = '🎉';
        break;
      case 'out_for_delivery':
        emoji = '🚚';
        break;
      case 'delivered':
        emoji = '✨';
        break;
    }

    await _notifications.show(
      orderId.hashCode,
      '$emoji Order ${status.replaceAll('_', ' ').toUpperCase()}',
      message,
      details,
      payload: orderId,
    );

    print(
      'NotificationService: Showed status notification for order $orderId (Role: ${userRole?.value ?? "default"})',
    );
  }

  /// Show a generic notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    UserRole? userRole,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = await _getAndroidDetails(
      channelId: 'general',
      channelName: 'General Notifications',
      channelDescription: 'General app notifications',
      role: userRole,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    final iosDetails = await _getIOSDetails(role: userRole);

    final NotificationDetails details = NotificationDetails(
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

    print(
      'NotificationService: Showed general notification (Role: ${userRole?.value ?? "default"})',
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

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
