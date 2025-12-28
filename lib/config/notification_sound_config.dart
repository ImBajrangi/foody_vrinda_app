import 'package:foody_vrinda/models/user_model.dart';

/// Configuration for notification sounds based on user roles
class NotificationSoundConfig {
  // Sound file names for different roles
  // NOTE: These sound files must be placed in:
  //   Android: android/app/src/main/res/raw/ (as .mp3 or .wav)
  //   iOS: Runner/Resources/ (as .caf or .aiff)
  static const String ownerSound = 'owner_notification';
  static const String kitchenSound = 'kitchen_notification';
  static const String deliverySound = 'delivery_notification';
  static const String defaultSound = 'default';

  // Set to true when custom sound files have been added
  static const bool _customSoundsEnabled = false;

  /// Get the sound resource name based on user role
  /// Returns null to use system default if custom sound is not configured
  static String? getSoundForRole(UserRole role) {
    // Return null to use system default sound when custom sounds are disabled
    if (!_customSoundsEnabled) {
      return null;
    }

    switch (role) {
      case UserRole.owner:
        return ownerSound;
      case UserRole.kitchen:
        return kitchenSound;
      case UserRole.delivery:
        return deliverySound;
      default:
        return null; // Use system default for customers and general notifications
    }
  }

  /// Get channel ID based on notification type and role
  static String getChannelId(String notificationType, UserRole? role) {
    if (role != null) {
      return '${notificationType}_${role.value}';
    }
    return notificationType;
  }

  /// Get channel name based on notification type and role
  static String getChannelName(String notificationType, UserRole? role) {
    final rolePrefix = role != null ? '${_getRoleDisplayName(role)} ' : '';
    final typeDisplay = _getNotificationTypeDisplay(notificationType);
    return '$rolePrefix$typeDisplay';
  }

  /// Get human-readable role name
  static String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.kitchen:
        return 'Kitchen';
      case UserRole.delivery:
        return 'Delivery';
      case UserRole.customer:
        return 'Customer';
      case UserRole.developer:
        return 'Developer';
    }
  }

  /// Get human-readable notification type
  static String _getNotificationTypeDisplay(String type) {
    switch (type) {
      case 'new_orders':
        return 'New Orders';
      case 'delivery_orders':
        return 'Delivery Orders';
      case 'order_updates':
        return 'Order Updates';
      case 'general':
        return 'General Notifications';
      default:
        return 'Notifications';
    }
  }

  /// Check if custom sound should be used based on platform and availability
  static bool shouldUseCustomSound() {
    // Custom sounds are supported on both Android and iOS
    // However, we'll return true only if sound files are present
    // This can be extended to check file existence if needed
    return true;
  }
}
