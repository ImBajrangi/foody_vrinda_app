import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../models/shop_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/review_model.dart';
import '../../services/shop_service.dart';
import '../../services/review_service.dart';
import '../../services/resource_cache_service.dart';
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
  final ReviewService _reviewService = ReviewService();
  late Stream<List<MenuItemModel>> _menuStream;
  bool _showInfo = false;

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
                          // Rating Stars
                          if (widget.shop.ratingCount > 0) ...[
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < widget.shop.rating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.shop.rating.toStringAsFixed(1)} (${widget.shop.ratingCount})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
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
                // Info toggle button
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    onPressed: () => setState(() => _showInfo = !_showInfo),
                    icon: Icon(
                      _showInfo ? Icons.grid_view : Icons.info_outline,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Menu content + Cart Summary overlay OR Info Panel
            Expanded(
              child: Stack(
                children: [
                  _showInfo
                      ? _buildInfoPanel()
                      : StreamBuilder<List<MenuItemModel>>(
                          stream: _menuStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: AnimatedLoader(
                                  message: 'Reading menu...',
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final menuItems = snapshot.data ?? [];

                            if (menuItems.isEmpty) {
                              return const EmptyState(
                                title: 'Menu is Empty',
                                subtitle:
                                    'This shop hasn\'t added any items yet.',
                                animationType: 'data',
                              );
                            }

                            // Proactively cache menu item images
                            final menuImages = menuItems
                                .map((i) => i.imageUrl)
                                .where((url) => url != null && url.isNotEmpty)
                                .cast<String>()
                                .toList();
                            if (menuImages.isNotEmpty) {
                              ResourceCacheService().cacheImages(menuImages);
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
                                    childAspectRatio: 0.65,
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
                                  originalPrice: item.originalPrice,
                                  imageUrl: item.imageUrl,
                                  isVeg: item.isVeg,
                                  rating: item.rating,
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

  Widget _buildInfoPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Order Queue (if enabled)
          if (widget.shop.showOrderQueue) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                ),
              ),
              child: StreamBuilder<int>(
                stream: _reviewService.streamPendingOrderCount(widget.shop.id),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Orders in Queue',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              count == 0
                                  ? 'No waiting orders'
                                  : '$count order${count > 1 ? 's' : ''} being prepared',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Waiting Time Section
            if (widget.shop.showWaitTime)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: StreamBuilder<int>(
                  stream: _reviewService.streamPendingOrderCount(
                    widget.shop.id,
                  ),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    final avgTime = widget.shop.estimatedWaitTime;

                    // Simple logic: Base time + 5 mins per order in queue
                    final minTime = avgTime + (count * 5);
                    final maxTime = minTime + 10;

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Est. Waiting Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                count > 0
                                    ? 'Including $count orders ahead of you'
                                    : 'Queue is clear! Ready soon.',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$minTime-$maxTime',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const Text(
                              'MINS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],

          // Reviews Section
          const Text(
            'CUSTOMER REVIEWS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<ReviewModel>>(
            stream: _reviewService.getReviews(widget.shop.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reviews = snapshot.data ?? [];

              if (reviews.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 48,
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Be the first to leave a review!',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: reviews
                    .map((review) => _buildReviewTile(review))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTile(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                backgroundImage: review.userPhotoUrl != null
                    ? NetworkImage(review.userPhotoUrl!)
                    : null,
                child: review.userPhotoUrl == null
                    ? Text(
                        review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < review.rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(review.createdAt),
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
