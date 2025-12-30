import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';
import '../models/menu_item_model.dart';

/// Represents a search result that can be either a Shop or a Menu Item
class SearchResult {
  final String type; // 'shop' or 'menuItem'
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final ShopModel? shop; // For direct navigation
  final MenuItemModel? menuItem;
  final String? shopId; // For menu items, to navigate to the shop

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.shop,
    this.menuItem,
    this.shopId,
  });
}

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Searches across shops and menu items
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final queryLower = query.toLowerCase().trim();
    final results = <SearchResult>[];

    // Search shops
    try {
      final shopsSnapshot = await _firestore.collection('shops').get();
      for (final doc in shopsSnapshot.docs) {
        final shop = ShopModel.fromFirestore(doc);
        final nameMatch = shop.name.toLowerCase().contains(queryLower);
        final addressMatch =
            shop.address?.toLowerCase().contains(queryLower) ?? false;

        if (nameMatch || addressMatch) {
          results.add(
            SearchResult(
              type: 'shop',
              id: shop.id,
              title: shop.name,
              subtitle: shop.address ?? 'Cloud Kitchen',
              imageUrl: shop.imageUrl,
              shop: shop,
            ),
          );
        }
      }
    } catch (e) {
      print('SearchService: Error searching shops: $e');
    }

    // Search menu items
    try {
      final menusSnapshot = await _firestore.collection('menus').get();
      for (final doc in menusSnapshot.docs) {
        final item = MenuItemModel.fromFirestore(doc);
        final nameMatch = item.name.toLowerCase().contains(queryLower);
        final categoryMatch =
            item.category?.toLowerCase().contains(queryLower) ?? false;
        final descriptionMatch =
            item.description?.toLowerCase().contains(queryLower) ?? false;

        if (nameMatch || categoryMatch || descriptionMatch) {
          results.add(
            SearchResult(
              type: 'menuItem',
              id: item.id,
              title: item.name,
              subtitle:
                  '${item.formattedPrice}${item.category != null ? ' • ${item.category}' : ''}',
              imageUrl: item.imageUrl,
              menuItem: item,
              shopId: item.shopId,
            ),
          );
        }
      }
    } catch (e) {
      print('SearchService: Error searching menu items: $e');
    }

    // Sort results: shops first, then menu items
    results.sort((a, b) {
      if (a.type == b.type) {
        return a.title.compareTo(b.title);
      }
      return a.type == 'shop' ? -1 : 1;
    });

    return results;
  }

  /// Get a shop by its ID (for navigating from menu item results)
  Future<ShopModel?> getShopById(String shopId) async {
    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();
      if (doc.exists) {
        return ShopModel.fromFirestore(doc);
      }
    } catch (e) {
      print('SearchService: Error getting shop: $e');
    }
    return null;
  }
}
