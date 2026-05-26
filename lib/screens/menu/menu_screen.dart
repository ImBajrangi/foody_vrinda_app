import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../widgets/animations.dart';
import '../../models/shop_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/review_model.dart';
import '../../services/shop_service.dart';
import '../../services/review_service.dart';
import '../../services/resource_cache_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_preferences_provider.dart';
import '../../widgets/cards.dart';
import '../cart/cart_screen.dart';
import '../../config/telegram_page_route.dart';

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
  String _selectedCategory = 'All';

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

  PreferredSizeWidget _buildCategoryTabBar(List<MenuItemModel> items) {
    final categories = [
      'All',
      ...items
          .map((e) => e.category ?? 'General')
          .toSet()
          .where((c) => c.isNotEmpty)
    ];

    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        height: 60,
        width: double.infinity,
        decoration:       BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(
            bottom: BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryOrange : AppTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryOrange : AppTheme.border,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: StreamBuilder<List<MenuItemModel>>(
        stream: _menuStream,
        builder: (context, snapshot) {
          final menuItems = snapshot.data ?? _shopService.getCachedMenuItems(widget.shop.id);

          if (menuItems.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: AnimatedLoader(
                message: 'Reading menu...',
              ),
            );
          }

          if (snapshot.hasError && menuItems.isEmpty) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (menuItems.isEmpty) {
            return const EmptyState(
              title: 'Menu is Empty',
              subtitle: 'This shop hasn\'t added any items yet.',
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

          final prefsProvider = Provider.of<UserPreferencesProvider>(context);
          var filteredItems = _selectedCategory == 'All'
              ? menuItems
              : menuItems.where((item) => (item.category ?? 'General') == _selectedCategory).toList();

          if (prefsProvider.dietaryFilter == 'veg') {
            filteredItems = filteredItems.where((item) => item.isVeg).toList();
          } else if (prefsProvider.dietaryFilter == 'jain') {
            filteredItems = filteredItems.where((item) {
              if (!item.isVeg) return false;
              final nameLower = item.name.toLowerCase();
              final descLower = (item.description ?? '').toLowerCase();
              return !nameLower.contains('onion') &&
                     !nameLower.contains('garlic') &&
                     !nameLower.contains('potato') &&
                     !descLower.contains('onion') &&
                     !descLower.contains('garlic') &&
                     !descLower.contains('potato');
            }).toList();
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: AppTheme.cardBackground,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                    child: Text(
                      widget.shop.name,
                      style:       TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  centerTitle: true,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back,
                        color: innerBoxIsScrolled ? AppTheme.textPrimary : Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: innerBoxIsScrolled ? Colors.transparent : Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        onPressed: () => setState(() => _showInfo = !_showInfo),
                        icon: Icon(
                          _showInfo ? Icons.grid_view : Icons.info_outline,
                          color: innerBoxIsScrolled ? AppTheme.textPrimary : Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: innerBoxIsScrolled ? Colors.transparent : Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  bottom: _showInfo ? null : _buildCategoryTabBar(menuItems),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'shop-${widget.shop.imageUrl ?? widget.shop.name}',
                          child: widget.shop.imageUrl != null && widget.shop.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.shop.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) =>       Icon(
                                    Icons.store,
                                    size: 80,
                                    color: AppTheme.textTertiary,
                                  ),
                                )
                              :       Icon(
                                  Icons.store,
                                  size: 80,
                                  color: AppTheme.textTertiary,
                                ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                                Colors.black.withValues(alpha: 0.95),
                              ],
                              stops: const [0.0, 0.4, 0.7, 1.0],
                            ),
                          ),
                        ),
                        // Premium Expanded Details Column (Fades out automatically during scroll)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: _showInfo ? 16 : 64,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.shop.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (widget.shop.ratingCount > 0) ...[
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.shop.rating.toStringAsFixed(1)} (${widget.shop.ratingCount} ratings)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: widget.shop.isOpen ? AppTheme.success : AppTheme.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.0),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.shop.isOpen ? 'Open Now' : 'Closed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: widget.shop.isOpen ? AppTheme.success : AppTheme.error,
                                      shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
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
                ),
              ];
            },
            body: Stack(
              children: [
                _showInfo
                    ? _buildInfoPanel()
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          cartProvider.isNotEmpty ? 100 : 16,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
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
                            description: item.description,
                            quantity: quantity,
                            onAdd: () => cartProvider.addItem(item),
                            onIncrement: () => cartProvider.incrementItem(item.id),
                            onDecrement: () => cartProvider.decrementItem(item.id),
                          ).animate()
                           .fade(duration: 250.ms)
                           .slideX(begin: 0.1, end: 0, duration: 250.ms, curve: Curves.easeOutBack);
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
                                  style:       TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  cartProvider.formattedTotal,
                                  style:       TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryOrange,
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
                                      TelegramPageRoute(
                                        child: CartScreen(shop: widget.shop),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryOrange,
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
          );
        },
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
                color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.3),
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
                          color: AppTheme.primaryOrange,
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
                              style:       TextStyle(
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
                          color: AppTheme.primaryOrange,
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
                                style:       TextStyle(
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
                Text(
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
                  child:       Center(
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
                backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                backgroundImage: review.userPhotoUrl != null
                    ? NetworkImage(review.userPhotoUrl!)
                    : null,
                child: review.userPhotoUrl == null
                    ? Text(
                        review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : 'A',
                        style:       TextStyle(
                          color: AppTheme.primaryOrange,
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
                style:       TextStyle(
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
              style:       TextStyle(
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
