/// App configuration constants
class AppConfig {
  // Developer email - automatically gets developer role
  static const String developerEmail = 'dev@vrinda.com';
  static const String developerPassword = 'dev123456';

  // Default placeholder images
  static const String defaultShopImage = '';
  static const String defaultFoodImage = '';
  static const String defaultUserAvatar =
      'https://ui-avatars.com/api/?background=0071E3&color=fff&name=';

  // App info
  static const String appName = 'Foody Vrinda';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Delicious food, delivered fast';

  // Placeholder food images - DEPRECATED
  static const List<String> foodPlaceholderImages = [];

  // Placeholder shop images - DEPRECATED
  static const List<String> shopPlaceholderImages = [];

  /// Get a placeholder image for shops (Legacy fallback)
  static String getRandomShopImage(String? shopId) => '';

  /// Get a placeholder image for food items (Legacy fallback)
  static String getRandomFoodImage(String? itemId) => '';

  // Whitelist of developer emails
  static const List<String> developerEmails = [
    'developer@foodyvrinda.com',
    'dev@foodyvrinda.com',
    'admin@foodyvrinda.com',
    'imbajrangi@gmail.com',
    'sakhi@foodyvrinda.com',
    'dev@vrinda.com',
  ];

  static const List<String> adminEmails = [
    'admin@foodyvrinda.com',
    'owner@foodyvrinda.com',
    'manager@foodyvrinda.com',
    'developer@foodyvrinda.com',
    'dev@foodyvrinda.com',
    'imbajrangi@gmail.com',
    'sakhi@foodyvrinda.com',
  ];

  /// Check if email is developer email
  static bool isDeveloperEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final clean = email.toLowerCase().trim();
    return developerEmails.contains(clean) ||
        clean.startsWith('dev@') ||
        clean.contains('+dev@');
  }

  /// Check if email is admin email
  static bool isAdminEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final clean = email.toLowerCase().trim();
    return adminEmails.contains(clean) || isDeveloperEmail(clean);
  }
}
