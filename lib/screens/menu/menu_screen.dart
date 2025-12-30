import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
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
  late Stream<List<MenuItemModel>> _menuStream;

  @override
  void initState() {
    super.initState();
    _menuStream = _shopService.getAvailableMenuItems(widget.shop.id);
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
            // Shop Banner
            Stack(
              children: [
                Hero(
                  tag: 'shop-${widget.shop.imageUrl ?? widget.shop.name}',
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(color: AppTheme.cardBackground),
                    child:
                        widget.shop.imageUrl != null &&
                            widget.shop.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.shop.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.store,
                              size: 80,
                              color: AppTheme.textTertiary,
                            ),
                          )
                        : const Icon(
                            Icons.store,
                            size: 80,
                            color: AppTheme.textTertiary,
                          ),
                  ),
                ),
                // Gradient Overlay for text legibility if needed
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
                // Back Button on top of banner
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Shop Name and Status on Banner
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.shop.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: widget.shop.isOpen
                                  ? AppTheme.success
                                  : AppTheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.shop.isOpen ? 'Open Now' : 'Closed',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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

            // Menu content + Cart Summary overlay
            Expanded(
              child: Stack(
                children: [
                  StreamBuilder<List<MenuItemModel>>(
                    stream: _menuStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: AnimatedLoader(message: 'Reading menu...'),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final menuItems = snapshot.data ?? [];

                      if (menuItems.isEmpty) {
                        return const EmptyState(
                          title: 'Menu is Empty',
                          subtitle: 'This shop hasn\'t added any items yet.',
                          animationType: 'data',
                        );
                      }

                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          cartProvider.isNotEmpty ? 100 : 16,
                        ),
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
                          final quantity = cartProvider.getItemQuantity(
                            item.id,
                          );

                          return MenuItemCard(
                            name: item.name,
                            price: item.price,
                            imageUrl: item.imageUrl,
                            quantity: quantity,
                            onAdd: () => cartProvider.addItem(item),
                            onIncrement: () =>
                                cartProvider.incrementItem(item.id),
                            onDecrement: () =>
                                cartProvider.decrementItem(item.id),
                          );
                        },
                      );
                    },
                  ),

                  // Animated Cart Summary
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.fastOutSlowIn,
                    bottom: cartProvider.isNotEmpty ? 0 : -120,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, -5),
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
                                foregroundColor: Colors.white,
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
                                    widget.shop.isOpen
                                        ? 'View Cart'
                                        : 'Shop Closed',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
