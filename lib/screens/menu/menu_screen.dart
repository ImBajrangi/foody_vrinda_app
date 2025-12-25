import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/shop_model.dart';
import '../../models/menu_item_model.dart';
import '../../services/shop_service.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cards.dart';
import '../cart/cart_screen.dart';

class MenuScreen extends StatefulWidget {
  final ShopModel shop;

  const MenuScreen({super.key, required this.shop});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ShopService _shopService = ShopService();

  @override
  void initState() {
    super.initState();
    // Set the shop ID in cart provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(
        context,
        listen: false,
      ).setShopId(widget.shop.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.background,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.shop.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.shop.isOpen
                                    ? AppTheme.success
                                    : AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.shop.isOpen ? 'Open Now' : 'Closed',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.shop.isOpen
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu content
            Expanded(
              child: StreamBuilder<List<MenuItemModel>>(
                stream: _shopService.getAvailableMenuItems(widget.shop.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final menuItems = snapshot.data ?? [];

                  if (menuItems.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No menu items available',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.7,
                        ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final quantity = cartProvider.getItemQuantity(item.id);

                      return MenuItemCard(
                        name: item.name,
                        price: item.price,
                        imageUrl: item.imageUrl,
                        quantity: quantity,
                        onAdd: () => cartProvider.addItem(item),
                        onIncrement: () => cartProvider.incrementItem(item.id),
                        onDecrement: () => cartProvider.decrementItem(item.id),
                      );
                    },
                  );
                },
              ),
            ),

            // Cart Summary
            if (cartProvider.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${cartProvider.totalItems} item${cartProvider.totalItems > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              cartProvider.formattedTotal,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: widget.shop.isOpen
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CartScreen(shop: widget.shop),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_bag, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.shop.isOpen ? 'View Cart' : 'Shop Closed',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
