import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';
import '../models/menu_item_model.dart';

class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all shops (without ordering to avoid index issues)
  Stream<List<ShopModel>> getShops() {
    return _firestore.collection('shops').snapshots().map((snapshot) {
      print('ShopService: Got ${snapshot.docs.length} shops');
      return snapshot.docs.map((doc) {
        try {
          final shop = ShopModel.fromFirestore(doc);
          print('ShopService: Parsed shop: ${shop.name}');
          return shop;
        } catch (e) {
          print('ShopService: Error parsing shop ${doc.id}: $e');
          return ShopModel(id: doc.id, name: 'Error loading shop');
        }
      }).toList();
    });
  }

  // Get single shop
  Future<ShopModel?> getShop(String shopId) async {
    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();
      if (doc.exists) {
        return ShopModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting shop: $e');
      return null;
    }
  }

  // Get shop stream
  Stream<ShopModel?> shopStream(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .snapshots()
        .map((doc) => doc.exists ? ShopModel.fromFirestore(doc) : null);
  }

  // Create shop
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

  // Update shop
  Future<void> updateShop(ShopModel shop) async {
    await _firestore
        .collection('shops')
        .doc(shop.id)
        .update(shop.toFirestore());
  }

  // Delete shop
  Future<void> deleteShop(String shopId) async {
    await _firestore.collection('shops').doc(shopId).delete();
  }

  // Get menu items for a shop (from 'menus' collection based on your Firebase structure)
  Stream<List<MenuItemModel>> getMenuItems(String shopId) {
    // Try 'menus' collection first (matching your Firebase structure)
    return _firestore
        .collection('menus')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
          print(
            'ShopService: Got ${snapshot.docs.length} menu items for shop $shopId',
          );
          return snapshot.docs.map((doc) {
            try {
              return MenuItemModel.fromFirestore(doc);
            } catch (e) {
              print('ShopService: Error parsing menu item ${doc.id}: $e');
              return MenuItemModel(
                id: doc.id,
                shopId: shopId,
                name: 'Error loading item',
                price: 0,
              );
            }
          }).toList();
        });
  }

  // Get available menu items for a shop
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

  // Add menu item
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

  // Update menu item
  Future<void> updateMenuItem(MenuItemModel item) async {
    await _firestore
        .collection('menus')
        .doc(item.id)
        .update(item.toFirestore());
  }

  // Delete menu item
  Future<void> deleteMenuItem(String itemId) async {
    await _firestore.collection('menus').doc(itemId).delete();
  }

  // Toggle menu item availability
  Future<void> toggleMenuItemAvailability(
    String itemId,
    bool isAvailable,
  ) async {
    await _firestore.collection('menus').doc(itemId).update({
      'isAvailable': isAvailable,
    });
  }
}
