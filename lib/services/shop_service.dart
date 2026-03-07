import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';
import '../models/menu_item_model.dart';

/// ShopService with singleton pattern and in-memory caching
class ShopService {
  // Singleton pattern
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === IN-MEMORY CACHE ===
  List<ShopModel>? _cachedShops;
  final Map<String, ShopModel> _shopCache = {};
  final Map<String, List<MenuItemModel>> _menuCache = {};

  /// Get all shops - direct Firestore stream with caching
  Stream<List<ShopModel>> getShops() {
    return _firestore.collection('shops').snapshots().map((snapshot) {
      final shops = snapshot.docs.map((doc) {
        try {
          final shop = ShopModel.fromFirestore(doc);
          _shopCache[shop.id] = shop; // Cache individual shop
          return shop;
        } catch (e) {
          return ShopModel(id: doc.id, name: 'Error loading shop');
        }
      }).toList();

      // Update cache
      _cachedShops = shops;
      return shops;
    });
  }

  /// Get cached shops synchronously (for instant access)
  List<ShopModel> getCachedShops() => _cachedShops ?? [];

  /// Get single shop - uses cache first, then Firestore
  Future<ShopModel?> getShop(String shopId) async {
    // Check cache first for instant response
    if (_shopCache.containsKey(shopId)) {
      return _shopCache[shopId];
    }

    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();
      if (doc.exists) {
        final shop = ShopModel.fromFirestore(doc);
        _shopCache[shopId] = shop;
        return shop;
      }
      return null;
    } catch (e) {
      print('Error getting shop: $e');
      return null;
    }
  }

  /// Get shop stream - for real-time updates on a specific shop
  Stream<ShopModel?> shopStream(String shopId) {
    return _firestore.collection('shops').doc(shopId).snapshots().map((doc) {
      if (doc.exists) {
        final shop = ShopModel.fromFirestore(doc);
        _shopCache[shopId] = shop;
        return shop;
      }
      return null;
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
    final shop = ShopModel(
      id: '',
      name: name,
      address: address,
      phoneNumber: phoneNumber,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      ownerId: ownerId,
      schedule: schedule,
    );

    final docRef = await _firestore.collection('shops').add(shop.toFirestore());
    return docRef.id;
  }

  /// Update shop
  Future<void> updateShop(ShopModel shop) async {
    await _firestore
        .collection('shops')
        .doc(shop.id)
        .update(shop.toFirestore());
    _shopCache[shop.id] = shop; // Update cache immediately
  }

  /// Delete shop
  Future<void> deleteShop(String shopId) async {
    await _firestore.collection('shops').doc(shopId).delete();
    _shopCache.remove(shopId);
    _cachedShops?.removeWhere((s) => s.id == shopId);
  }

  /// Get menu items for a shop
  Stream<List<MenuItemModel>> getMenuItems(String shopId) {
    return _firestore
        .collection('menus')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) {
            try {
              return MenuItemModel.fromFirestore(doc);
            } catch (e) {
              return MenuItemModel(
                id: doc.id,
                shopId: shopId,
                name: 'Error loading item',
                price: 0,
              );
            }
          }).toList();

          // Cache menu items
          _menuCache[shopId] = items;
          return items;
        });
  }

  /// Get cached menu items synchronously
  List<MenuItemModel> getCachedMenuItems(String shopId) =>
      _menuCache[shopId] ?? [];

  Stream<List<MenuItemModel>> getAllMenuItems() {
    return _firestore.collection('menus').snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        try {
          return MenuItemModel.fromFirestore(doc);
        } catch (e) {
          return MenuItemModel(
            id: doc.id,
            shopId: '',
            name: 'Error loading item',
            price: 0,
          );
        }
      }).toList();
      return items;
    });
  }

  /// Get available menu items for a shop
  Stream<List<MenuItemModel>> getAvailableMenuItems(String shopId) {
    return _firestore
        .collection('menus')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MenuItemModel.fromFirestore(doc))
              .where((item) => item.isAvailable)
              .toList(),
        );
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
    final item = MenuItemModel(
      id: '',
      shopId: shopId,
      name: name,
      price: price,
      imageUrl: imageUrl,
      category: category,
      description: description,
    );

    final docRef = await _firestore.collection('menus').add(item.toFirestore());
    return docRef.id;
  }

  /// Update menu item
  Future<void> updateMenuItem(MenuItemModel item) async {
    await _firestore
        .collection('menus')
        .doc(item.id)
        .update(item.toFirestore());
  }

  /// Delete menu item
  Future<void> deleteMenuItem(String itemId) async {
    await _firestore.collection('menus').doc(itemId).delete();
  }

  /// Toggle menu item availability
  Future<void> toggleMenuItemAvailability(
    String itemId,
    bool isAvailable,
  ) async {
    await _firestore.collection('menus').doc(itemId).update({
      'isAvailable': isAvailable,
    });
  }
}
