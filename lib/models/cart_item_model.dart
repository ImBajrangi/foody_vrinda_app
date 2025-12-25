import 'menu_item_model.dart';

class CartItemModel {
  final MenuItemModel menuItem;
  int quantity;

  CartItemModel({required this.menuItem, this.quantity = 1});

  double get total => menuItem.price * quantity;

  String get formattedTotal => '₹${total.toStringAsFixed(0)}';

  CartItemModel copyWith({MenuItemModel? menuItem, int? quantity}) {
    return CartItemModel(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
    );
  }
}
