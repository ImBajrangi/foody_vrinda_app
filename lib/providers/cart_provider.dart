import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/menu_item_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  String? _shopId;

  List<CartItemModel> get items => List.unmodifiable(_items);
  String? get shopId => _shopId;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.total);

  String get formattedTotal => '₹${totalAmount.toStringAsFixed(0)}';

  void setShopId(String? id) {
    if (_shopId != id) {
      // Clear cart when switching shops
      _items.clear();
      _shopId = id;
      notifyListeners();
    }
  }

  void addItem(MenuItemModel menuItem) {
    final existingIndex = _items.indexWhere(
      (item) => item.menuItem.id == menuItem.id,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItemModel(menuItem: menuItem));
    }

    notifyListeners();
  }

  void removeItem(String menuItemId) {
    _items.removeWhere((item) => item.menuItem.id == menuItemId);
    notifyListeners();
  }

  void incrementItem(String menuItemId) {
    final index = _items.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrementItem(String menuItemId) {
    final index = _items.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }

    final index = _items.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  int getItemQuantity(String menuItemId) {
    final item = _items
        .where((item) => item.menuItem.id == menuItemId)
        .firstOrNull;
    return item?.quantity ?? 0;
  }

  bool hasItem(String menuItemId) {
    return _items.any((item) => item.menuItem.id == menuItemId);
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void clearAndSetShop(String? shopId) {
    _items.clear();
    _shopId = shopId;
    notifyListeners();
  }
}
