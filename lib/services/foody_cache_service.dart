import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shop_model.dart';
import '../models/menu_item_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// FOODY CACHE SERVICE - Persistent storage for zero-latency startups
/// ═══════════════════════════════════════════════════════════════════════════

class FoodyCacheService {
  static final FoodyCacheService _instance = FoodyCacheService._internal();
  factory FoodyCacheService() => _instance;
  FoodyCacheService._internal();

  SharedPreferences? _prefs;
  
  static const String _shopsKey = 'cached_foody_shops';
  static const String _shopsTimeKey = 'cached_foody_shops_time';
  static const String _menuKeyPrefix = 'cached_menu_';
  static const String _menuTimeKeyPrefix = 'cached_menu_time_';
  
  static const Duration _cacheExpiry = Duration(hours: 4);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if cache is still valid
  bool _isCacheValid(String timestampKey) {
    if (_prefs == null) return false;
    final timeStr = _prefs!.getString(timestampKey);
    if (timeStr == null) return false;
    final lastCacheTime = DateTime.tryParse(timeStr);
    if (lastCacheTime == null) return false;
    return DateTime.now().difference(lastCacheTime) < _cacheExpiry;
  }

  /// Get cached shops
  List<ShopModel>? getCachedShops() {
    if (_prefs == null) return null;
    if (!_isCacheValid(_shopsTimeKey)) return null;

    final jsonStr = _prefs!.getString(_shopsKey);
    if (jsonStr == null) return null;

    try {
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((item) {
        final map = Map<String, dynamic>.from(item);
        final scheduleMap = map['schedule'] != null ? Map<String, dynamic>.from(map['schedule']) : null;
        final alarmMap = map['alarmSettings'] != null ? Map<String, dynamic>.from(map['alarmSettings']) : null;
        
        DateTime? createdAt;
        if (map['createdAt'] != null) {
          createdAt = DateTime.tryParse(map['createdAt'].toString());
        }

        return ShopModel(
          id: map['id'] ?? '',
          name: map['name'] ?? '',
          address: map['address'],
          phoneNumber: map['phoneNumber'],
          latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
          longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
          imageUrl: map['image'],
          ownerId: map['ownerId'],
          schedule: ShopSchedule.fromMap(scheduleMap),
          alarmSettings: AlarmSettings.fromMap(alarmMap),
          createdAt: createdAt,
          rating: map['rating'] != null ? (map['rating'] as num).toDouble() : 0.0,
          ratingCount: map['ratingCount'] ?? 0,
          showOrderQueue: map['showOrderQueue'] ?? false,
          estimatedWaitTime: map['estimatedWaitTime'] ?? 15,
          showWaitTime: map['showWaitTime'] ?? false,
          minimumOrderAmount: map['minimumOrderAmount'] != null ? (map['minimumOrderAmount'] as num).toDouble() : 0.0,
          deliveryCharge: map['deliveryCharge'] != null ? (map['deliveryCharge'] as num).toDouble() : 0.0,
          gstPercentage: map['gstPercentage'] != null ? (map['gstPercentage'] as num).toDouble() : 5.0,
          discountTag: map['discountTag'],
          discountDescription: map['discountDescription'],
        );
      }).toList();
    } catch (e) {
      return null;
    }
  }

  /// Save shops to cache
  Future<void> cacheShops(List<ShopModel> shops) async {
    if (_prefs == null) await init();
    
    try {
      final List<Map<String, dynamic>> serialized = shops.map((shop) {
        return {
          'id': shop.id,
          'name': shop.name,
          'address': shop.address,
          'phoneNumber': shop.phoneNumber,
          'latitude': shop.latitude,
          'longitude': shop.longitude,
          'image': shop.imageUrl,
          'ownerId': shop.ownerId,
          'schedule': shop.schedule.toMap(),
          'alarmSettings': shop.alarmSettings.toMap(),
          'createdAt': shop.createdAt?.toIso8601String(),
          'rating': shop.rating,
          'ratingCount': shop.ratingCount,
          'showOrderQueue': shop.showOrderQueue,
          'estimatedWaitTime': shop.estimatedWaitTime,
          'showWaitTime': shop.showWaitTime,
          'minimumOrderAmount': shop.minimumOrderAmount,
          'deliveryCharge': shop.deliveryCharge,
          'gstPercentage': shop.gstPercentage,
          'discountTag': shop.discountTag,
          'discountDescription': shop.discountDescription,
        };
      }).toList();

      await _prefs!.setString(_shopsKey, json.encode(serialized));
      await _prefs!.setString(_shopsTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      // Fail silently
    }
  }

  /// Get cached menu items for a shop
  List<MenuItemModel>? getCachedMenuItems(String shopId) {
    if (_prefs == null) return null;
    final timeKey = '$_menuTimeKeyPrefix$shopId';
    if (!_isCacheValid(timeKey)) return null;

    final jsonStr = _prefs!.getString('$_menuKeyPrefix$shopId');
    if (jsonStr == null) return null;

    try {
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((item) {
        final map = Map<String, dynamic>.from(item);
        
        DateTime? createdAt;
        if (map['createdAt'] != null) {
          createdAt = DateTime.tryParse(map['createdAt'].toString());
        }

        return MenuItemModel(
          id: map['id'] ?? '',
          shopId: map['shopId'] ?? '',
          name: map['name'] ?? '',
          price: map['price'] != null ? (map['price'] as num).toDouble() : 0.0,
          originalPrice: map['originalPrice'] != null ? (map['originalPrice'] as num).toDouble() : null,
          imageUrl: map['imageUrl'],
          isAvailable: map['isAvailable'] ?? true,
          category: map['category'],
          description: map['description'],
          isVeg: map['isVeg'] ?? true,
          rating: map['rating'] != null ? (map['rating'] as num).toDouble() : 0.0,
          ratingCount: map['ratingCount'] ?? 0,
          createdAt: createdAt,
        );
      }).toList();
    } catch (e) {
      return null;
    }
  }

  /// Save menu items to cache
  Future<void> cacheMenuItems(String shopId, List<MenuItemModel> items) async {
    if (_prefs == null) await init();

    try {
      final List<Map<String, dynamic>> serialized = items.map((item) {
        return {
          'id': item.id,
          'shopId': item.shopId,
          'name': item.name,
          'price': item.price,
          'originalPrice': item.originalPrice,
          'imageUrl': item.imageUrl,
          'isAvailable': item.isAvailable,
          'category': item.category,
          'description': item.description,
          'isVeg': item.isVeg,
          'rating': item.rating,
          'ratingCount': item.ratingCount,
          'createdAt': item.createdAt?.toIso8601String(),
        };
      }).toList();

      await _prefs!.setString('$_menuKeyPrefix$shopId', json.encode(serialized));
      await _prefs!.setString('$_menuTimeKeyPrefix$shopId', DateTime.now().toIso8601String());
    } catch (e) {
      // Fail silently
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    if (_prefs == null) await init();
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith('cached_foody_') || key.startsWith('cached_menu_')) {
        await _prefs!.remove(key);
      }
    }
  }
}
