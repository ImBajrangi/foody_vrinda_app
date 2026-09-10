import '../models/shop_model.dart';
import '../models/menu_item_model.dart';
import 'foody_cache_service.dart';
import 'supabase_service.dart';

/// ShopService with singleton pattern and high-performance Supabase + local caching
class ShopService {
  // Singleton pattern
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  final SupabaseService _supabase = SupabaseService();

  // === IN-MEMORY CACHE ===
  List<ShopModel>? _cachedShops;
  final Map<String, ShopModel> _shopCache = {};
  final Map<String, List<MenuItemModel>> _menuCache = {};

  /// Get all shops - real-time Supabase stream with automatic caching & fallback
  Stream<List<ShopModel>> getShops() {
    return _supabase.streamShops().map((records) {
      if (records.isNotEmpty) {
        final shops = records.map((data) {
          try {
            final shop = ShopModel.fromMap(data);
            _shopCache[shop.id] = shop;
            return shop;
          } catch (e) {
            return ShopModel(id: data['id']?.toString() ?? '', name: data['name']?.toString() ?? 'Shop');
          }
        }).toList();

        _cachedShops = shops;
        FoodyCacheService().cacheShops(shops);
        return shops;
      }

      // If empty or loading, fallback to local cache
      return getCachedShops();
    }).handleError((error) {
      print('ShopService.getShops Supabase error, falling back: $error');
      return getCachedShops();
    });
  }

  /// Get cached shops synchronously (for instant zero-latency startup)
  List<ShopModel> getCachedShops() {
    if (_cachedShops != null && _cachedShops!.isNotEmpty) {
      return _cachedShops!;
    }

    // Load from local persistent cache
    final localShops = FoodyCacheService().getCachedShops();
    if (localShops != null && localShops.isNotEmpty) {
      _cachedShops = localShops;
      for (final shop in localShops) {
        _shopCache[shop.id] = shop;
      }
      return localShops;
    }

    return [];
  }

  /// Get single shop - uses cache first, then Supabase
  Future<ShopModel?> getShop(String shopId) async {
    // Check cache first for instant response
    if (_shopCache.containsKey(shopId)) {
      return _shopCache[shopId];
    }

    try {
      final data = await _supabase.getShopById(shopId);
      if (data != null) {
        final shop = ShopModel.fromMap(data);
        _shopCache[shopId] = shop;
        return shop;
      }
    } catch (e) {
      print('ShopService.getShop Supabase error: $e');
    }

    return null;
  }

  /// Get shop stream - for real-time updates on a specific shop
  Stream<ShopModel?> shopStream(String shopId) {
    return _supabase.streamShops().map((shops) {
      final match = shops.where((s) => (s['id']?.toString() ?? '') == shopId).toList();
      if (match.isNotEmpty) {
        final shop = ShopModel.fromMap(match.first);
        _shopCache[shopId] = shop;
        return shop;
      }
      return _shopCache[shopId];
    });
  }

  /// Create shop
  Future<String> createShop({
    required String name,
    String? address,
    String? phoneNumber,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? ownerId,
    ShopSchedule? schedule,
  }) async {
    final shopId = 'shop-${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'id': shopId,
      'name': name,
      'address': address ?? '',
      'phone': phoneNumber,
      'coordinates': {'lat': latitude ?? 27.5706, 'lng': longitude ?? 77.6593},
      'image': imageUrl,
      'owner_id': ownerId,
      'is_open': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _supabase.client.from('foody_shops').insert(payload);
    } catch (e) {
      print('ShopService.createShop error: $e');
    }
    return shopId;
  }

  /// Update shop
  Future<void> updateShop(ShopModel shop) async {
    final payload = {
      'name': shop.name,
      'address': shop.address,
      'phone': shop.phoneNumber,
      'coordinates': {'lat': shop.latitude ?? 27.5706, 'lng': shop.longitude ?? 77.6593},
      'image': shop.imageUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _supabase.client
          .from('foody_shops')
          .update(payload)
          .eq('id', shop.id);
    } catch (e) {
      print('ShopService.updateShop error: $e');
    }
    _shopCache[shop.id] = shop;
  }

  /// Delete shop
  Future<void> deleteShop(String shopId) async {
    try {
      await _supabase.client
          .from('foody_shops')
          .delete()
          .eq('id', shopId);
    } catch (e) {
      print('ShopService.deleteShop error: $e');
    }
    _shopCache.remove(shopId);
    _cachedShops?.removeWhere((s) => s.id == shopId);
  }

  /// Get menu items for a shop
  Stream<List<MenuItemModel>> getMenuItems(String shopId) {
    return _supabase.streamMenuItems(shopId).map((records) {
      if (records.isNotEmpty) {
        final items = records.map((data) => MenuItemModel.fromMap(data)).toList();
        _menuCache[shopId] = items;
        FoodyCacheService().cacheMenuItems(shopId, items);
        return items;
      }
      return getCachedMenuItems(shopId);
    }).handleError((err) {
      print('ShopService.getMenuItems Supabase stream error: $err');
      return getCachedMenuItems(shopId);
    });
  }

  /// Get cached menu items synchronously
  List<MenuItemModel> getCachedMenuItems(String shopId) {
    if (_menuCache.containsKey(shopId) && _menuCache[shopId]!.isNotEmpty) {
      return _menuCache[shopId]!;
    }

    // Load from local persistent cache
    final localItems = FoodyCacheService().getCachedMenuItems(shopId);
    if (localItems != null && localItems.isNotEmpty) {
      _menuCache[shopId] = localItems;
      return localItems;
    }

    return [];
  }

  Stream<List<MenuItemModel>> getAllMenuItems() {
    return _supabase.client
        .from('foody_menus')
        .stream(primaryKey: ['id'])
        .map((records) => records.map((data) => MenuItemModel.fromMap(data)).toList())
        .handleError((_) => <MenuItemModel>[]);
  }

  /// Get available menu items for a shop
  Stream<List<MenuItemModel>> getAvailableMenuItems(String shopId) {
    return getMenuItems(shopId).map((items) => items.where((i) => i.isAvailable).toList());
  }

  /// Add menu item
  Future<String> addMenuItem({
    required String shopId,
    required String name,
    required double price,
    String? imageUrl,
    String? category,
    String? description,
  }) async {
    final itemId = 'menu-${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'id': itemId,
      'shop_id': shopId,
      'name': name,
      'price': price,
      'image': imageUrl,
      'category': category ?? 'Meals',
      'description': description,
      'is_available': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _supabase.client.from('foody_menus').insert(payload);
    } catch (e) {
      print('ShopService.addMenuItem error: $e');
    }
    return itemId;
  }

  /// Update menu item
  Future<void> updateMenuItem(MenuItemModel item) async {
    try {
      await _supabase.client
          .from('foody_menus')
          .update({
            'name': item.name,
            'price': item.price,
            'image': item.imageUrl,
            'category': item.category,
            'description': item.description,
            'is_available': item.isAvailable,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', item.id);
    } catch (e) {
      print('ShopService.updateMenuItem error: $e');
    }
  }

  /// Delete menu item
  Future<void> deleteMenuItem(String itemId) async {
    try {
      await _supabase.client
          .from('foody_menus')
          .delete()
          .eq('id', itemId);
    } catch (e) {
      print('ShopService.deleteMenuItem error: $e');
    }
  }

  /// Toggle menu item availability
  Future<void> toggleMenuItemAvailability(
    String itemId,
    bool isAvailable,
  ) async {
    try {
      await _supabase.client
          .from('foody_menus')
          .update({'is_available': isAvailable})
      .eq('id', itemId);
    } catch (e) {
      print('ShopService.toggleMenuItemAvailability error: $e');
    }
  }
}
