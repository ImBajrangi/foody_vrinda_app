import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class EmojiToIcon {
  static IconData getIcon(String emoji) {
    final cleanEmoji = emoji.replaceAll('️', '').trim(); // Remove variant selector and spaces
    switch (cleanEmoji) {
      case '🌅':
        return Icons.wb_sunny_outlined;
      case '☀️':
      case '🌤️':
      case '🌤':
        return Icons.wb_sunny_outlined;
      case '🍽️':
      case '🍽':
        return Icons.restaurant_outlined;
      case '🌆':
        return Icons.wb_twilight_outlined;
      case '🌙':
        return Icons.nightlight_round_outlined;
      case '👋':
        return Icons.waving_hand_outlined;
      case '🍕':
        return Icons.local_pizza_outlined;
      case '🍔':
        return Icons.fastfood_outlined;
      case '🥦':
        return Icons.eco_outlined;
      case '🌾':
        return Icons.grain_outlined;
      case '🥗':
        return Icons.restaurant_menu_outlined;
      case '🍰':
        return Icons.cake_outlined;
      case '🥪':
        return Icons.breakfast_dining_outlined;
      case '🥔':
        return Icons.cookie_outlined;
      case '🍅':
        return Icons.eco_outlined;
      case '🛍️':
      case '🛍':
        return Iconsax.shopping_bag;
      case '🚚':
        return Iconsax.truck;
      case '📦':
        return Iconsax.box;
      case '✅':
        return Iconsax.tick_circle;
      case '🎉':
        return Icons.celebration_outlined;
      case '✨':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  static Widget getIconWidget(String emoji, {double size = 24.0, Color? color}) {
    final cleanEmoji = emoji.replaceAll('️', '').trim();
    switch (cleanEmoji) {
      case '🛍️':
      case '🛍':
        return Icon(Iconsax.shopping_bag, size: size, color: color);
      case '🚚':
        return Icon(Iconsax.truck, size: size, color: color);
      case '📦':
        return Icon(Iconsax.box, size: size, color: color);
      case '✅':
        return Icon(Iconsax.tick_circle, size: size, color: color);
      case '👋':
        return Icon(Icons.waving_hand_outlined, size: size, color: color ?? Colors.orangeAccent);
      case '🍕':
        return Icon(Icons.local_pizza_outlined, size: size, color: color);
      case '🍔':
        return Icon(Icons.fastfood_outlined, size: size, color: color);
      case '🥦':
        return Icon(Icons.eco_outlined, size: size, color: color ?? Colors.green);
      case '🌾':
        return Icon(Icons.grain_outlined, size: size, color: color ?? Colors.amber);
      case '🥗':
        return Icon(Icons.restaurant_menu_outlined, size: size, color: color);
      case '🍰':
        return Icon(Icons.cake_outlined, size: size, color: color);
      case '🥪':
        return Icon(Icons.breakfast_dining_outlined, size: size, color: color);
      default:
        return Icon(getIcon(emoji), size: size, color: color);
    }
  }
}
