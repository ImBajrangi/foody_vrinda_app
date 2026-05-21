import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../config/design_system.dart';
import 'package:lottie/lottie.dart';
import '../../config/lottie_assets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../models/menu_item_model.dart';
import '../../services/shop_service.dart';
import '../../services/resource_cache_service.dart';
import '../../widgets/cards.dart';
import '../menu/menu_screen.dart';
import '../cart/cart_screen.dart';
import '../auth/login_screen.dart';
import '../kitchen/kitchen_view.dart';
import '../delivery/delivery_view.dart';
import '../delivery/delivery_dashboard_view.dart';
import '../dashboard/dashboard_view.dart';
import '../developer/developer_panel.dart';
import '../search/search_screen.dart';
import '../order/order_history_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../../widgets/animations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ShopService _shopService = ShopService();
  int _selectedViewIndex = 0;
  int _customerTabIndex = 0;
  late Stream<List<ShopModel>> _shopsStream;
  late Stream<List<MenuItemModel>> _trendingStream;

  @override
  void initState() {
    super.initState();
    _shopsStream = _shopService.getShops();
    _trendingStream = _shopService.getAllMenuItems();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;
    final role = userData?.role ?? UserRole.customer;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header (Only show on customer Home tab)
            if (_selectedViewIndex == 0 && _customerTabIndex == 0)
              _buildHeader(context, authProvider, userData),

            // View Switcher
            if (role != UserRole.customer) _buildViewSwitcher(userData, role),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      bottomNavigationBar: _selectedViewIndex == 0 ? _buildCustomerBottomNavBar() : null,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthProvider authProvider,
    UserModel? userData,
  ) {
    final cartProvider = Provider.of<CartProvider>(context);
    FoodyTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${userData?.displayName?.split(' ').first ?? 'Foodie'}! 👋',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ).animate().fadeIn(duration: 400.ms).shimmer(duration: 1500.ms, color: AppTheme.primaryOrange.withValues(alpha: 0.15)),
                    const SizedBox(height: 2),
                    const Text(
                      'What would you like to eat?',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                children: [
                  // Cart badge (for customers)
                  if (_selectedViewIndex == 0 && cartProvider.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );
                      },
                      icon: Stack(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 22),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                cartProvider.totalItems.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Order history icon
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _customerTabIndex = 2;
                      });
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 22),
                    tooltip: 'My Orders',
                  ),

                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationSettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined, size: 22),
                  ),

                  // Profile Avatar Only
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _customerTabIndex = 3;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child:
                              userData?.photoURL != null &&
                                  userData!.photoURL!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: userData.photoURL!,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      _buildInitialsAvatar(userData),
                                )
                              : _buildInitialsAvatar(userData),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Modern Search Bar
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              setState(() {
                _customerTabIndex = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: AppTheme.primaryOrange,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search delicious food, shops...',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.tune_rounded,
                    color: AppTheme.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher(UserModel? userData, UserRole role) {
    List<Map<String, dynamic>> views = [
      {'name': 'Shop', 'icon': Icons.store},
    ];

    if (role == UserRole.kitchen ||
        role == UserRole.owner ||
        role == UserRole.developer) {
      views.add({'name': 'Kitchen', 'icon': Icons.kitchen});
    }

    if (role == UserRole.delivery ||
        role == UserRole.owner ||
        role == UserRole.developer) {
      views.add({'name': 'Delivery', 'icon': Icons.delivery_dining});
    }

    // Dashboard for delivery staff
    if (role == UserRole.delivery) {
      views.add({
        'name': 'Dashboard',
        'icon': Icons.dashboard,
        'color': AppTheme.success,
      });
    }

    if (role == UserRole.owner || role == UserRole.developer) {
      views.add({
        'name': 'Dashboard',
        'icon': Icons.dashboard,
        'color': AppTheme.ownerColor,
      });
    }

    final hasDevAccess =
        role == UserRole.developer ||
        (role == UserRole.owner &&
            (userData?.devPermissions.isNotEmpty ?? false));
    if (hasDevAccess) {
      views.add({
        'name': 'Dev Panel',
        'icon': Icons.code,
        'color': AppTheme.developerColor,
      });
    }

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: List.generate(views.length, (index) {
              final view = views[index];
              final isSelected = _selectedViewIndex == index;
              final color = view['color'] as Color? ?? AppTheme.primaryOrange;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedViewIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        view['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        view['name'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.userData;
    final role = userData?.role ?? UserRole.customer;

    // We must ensure the children here exactly match the views structure
    // defined in _buildViewSwitcher to maintain consistent indexing.
    List<Widget> views = [_buildCustomerView()];

    if (role == UserRole.kitchen ||
        role == UserRole.owner ||
        role == UserRole.developer) {
      views.add(_buildKitchenView(userData));
    }

    if (role == UserRole.delivery ||
        role == UserRole.owner ||
        role == UserRole.developer) {
      views.add(_buildDeliveryView(userData));
    }

    // Delivery Dashboard for delivery staff
    if (role == UserRole.delivery) {
      views.add(_buildDeliveryDashboardView(userData));
    }

    if (role == UserRole.owner || role == UserRole.developer) {
      views.add(_buildDashboardView(userData));
    }

    final hasDevAccess =
        role == UserRole.developer ||
        (role == UserRole.owner &&
            (userData?.devPermissions.isNotEmpty ?? false));
    if (hasDevAccess) {
      views.add(_buildDevPanel());
    }

    return IndexedStack(index: _selectedViewIndex, children: views);
  }

  Widget _buildCustomerView() {
    switch (_customerTabIndex) {
      case 0:
        return _buildCustomerHomeTab();
      case 1:
        return const SearchScreen(isInline: true);
      case 2:
        return const OrderHistoryScreen(isInline: true);
      case 3:
        return _buildProfileTab();
      default:
        return _buildCustomerHomeTab();
    }
  }

  Widget _buildCustomerHomeTab() {
    return StreamBuilder<List<ShopModel>>(
      stream: _shopsStream,
      builder: (context, snapshot) {
        final shops = snapshot.data ?? _shopService.getCachedShops();

        if (shops.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: AnimatedLoader(message: 'Loading shops...'),
          );
        }

        if (snapshot.hasError && shops.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading shops',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (shops.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    size: 80,
                    color: AppTheme.textTertiary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No shops available yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check back soon for delicious food options!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        // Proactively cache shop images in the background
        final shopImages = shops
            .map((s) => s.imageUrl)
            .where((url) => url != null && url.isNotEmpty)
            .cast<String>()
            .toList();
        if (shopImages.isNotEmpty) {
          ResourceCacheService().cacheImages(shopImages);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // What's on your mind? - Category Icons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "What's on your mind?",
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildCategoryChip(
                      '🍕',
                      'Pizza',
                      lottieAsset: LottieAssets.pizzaSlices,
                    ),
                    _buildCategoryChip('🍔', 'Burger'),
                    _buildCategoryChip(
                      '🥦',
                      'Broccoli',
                      lottieAsset: LottieAssets.walkingBroccoli,
                    ),
                    _buildCategoryChip(
                      '🥔',
                      'Potato',
                      lottieAsset: LottieAssets.potato,
                    ),
                    _buildCategoryChip(
                      '🍅',
                      'Tomato',
                      lottieAsset: LottieAssets.growingTomatoes,
                    ),
                    _buildCategoryChip('🥗', 'Salad'),
                    _buildCategoryChip('🍰', 'Desserts'),
                    _buildCategoryChip('🥪', 'Sandwich'),
                  ],
                ),
              ),
              // Special Offers Bar
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildSpecialOffersBar(shops),
              ),

              const SizedBox(height: 16),

              // Trending Items Section
              _buildTrendingItemsSection(shops),

              const SizedBox(height: 16),

              // Shops Section Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Restaurants to explore 🍽️',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${shops.length} places',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Choose where you'd like to order from",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),

              // Shops List
              ...shops.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final shop = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ShopCard(
                      name: shop.name,
                      address: shop.address,
                      imageUrl: shop.imageUrl,
                      isOpen: shop.isOpen,
                      schedule: shop.schedule.displaySchedule,
                      rating: shop.rating > 0 ? shop.rating : null,
                      deliveryTime: shop.showWaitTime
                          ? '${shop.estimatedWaitTime} min'
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MenuScreen(shop: shop),
                          ),
                        );
                      },
                    ).animate().fade(delay: (index * 80).ms, duration: 350.ms).slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Get a premium gradient based on shop index (avoiding green)
  LinearGradient _getOfferGradient(int index) {
    final gradients = [
      // Flame Orange
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8C00), Color(0xFFFF4500)],
      ),
      // Deep Red / Pink
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      ),
      // Royal Blue
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
      ),
      // Mystic Purple
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      ),
      // Midnight Teal (Blue-ish, not green)
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2C3E50), Color(0xFF000000)],
      ),
    ];

    return gradients[index % gradients.length];
  }

  /// Get a matching shadow color for the gradient
  Color _getOfferShadow(int index) {
    final colors = [
      const Color(0xFFFF4500), // Orange
      const Color(0xFFFF416C), // Red
      const Color(0xFF2193B0), // Blue
      const Color(0xFF8E2DE2), // Purple
      const Color(0xFF2C3E50), // Teal/Dark
    ];
    return colors[index % colors.length].withValues(alpha: 0.3);
  }

  /// Build professional special offers bar
  Widget _buildSpecialOffersBar(List<ShopModel> shops) {
    final shopsWithOffers = shops
        .where((s) => s.discountTag != null && s.discountTag!.isNotEmpty)
        .toList();

    if (shopsWithOffers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Exclusive Offers for You',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 95,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: shopsWithOffers.length,
            itemBuilder: (context, index) {
              final shop = shopsWithOffers[index];
              return _buildOfferCard(shop, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(ShopModel shop, int index) {
    final gradient = _getOfferGradient(index);
    final shadowColor = _getOfferShadow(index);
    final primaryColor = gradient.colors.first;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MenuScreen(shop: shop)),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                Icons.local_offer,
                size: 80,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      shop.discountTag!,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    shop.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (shop.discountDescription != null)
                    Text(
                      shop.discountDescription!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String? emoji,
    String label, {
    String? lottieAsset,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigate to search with category filter
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      },
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    const Color(0xFFF1F5F9),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: lottieAsset != null
                    ? LottieAssets.build(
                        lottieAsset,
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            emoji ?? '🍴',
                            style: const TextStyle(fontSize: 26),
                          );
                        },
                      )
                    : Text(emoji ?? '🍴', style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Build trending items section with horizontal scroll
  Widget _buildTrendingItemsSection(List<ShopModel> shops) {
    if (shops.isEmpty) return const SizedBox.shrink();

    // Create a map of shopId -> ShopModel for quick lookup
    final shopMap = {for (var shop in shops) shop.id: shop};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                'Trending dishes near you!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: StreamBuilder<List<MenuItemModel>>(
            stream: _trendingStream,
            builder: (context, menuSnapshot) {
              // Handle loading state
              if (menuSnapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return _buildTrendingItemPlaceholder();
                  },
                );
              }

              // Handle error state
              if (menuSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.textTertiary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load trending dishes',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Handle empty state
              final items = menuSnapshot.data ?? [];
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          color: AppTheme.textTertiary.withOpacity(0.5),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No dishes available yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Show actual items (limit to 8)
              final displayItems = items.take(8).toList();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final item = displayItems[index];
                  // Get the shop for this item, fallback to first shop if not found
                  final shop = shopMap[item.shopId] ?? shops.first;
                  return _buildTrendingItemCard(item, shop);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build a trending item card
  Widget _buildTrendingItemCard(MenuItemModel item, ShopModel shop) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final _ = cartProvider.getItemQuantity(item.id);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MenuScreen(shop: shop)),
            );
          },
          child: Container(
            width: 145,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with badges overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child:
                            item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppTheme.background,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    _buildItemPlaceholder(),
                              )
                            : _buildItemPlaceholder(),
                      ),
                    ),
                    // Veg/Non-veg indicator overlay
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildVegIndicator(item.isVeg),
                    ),
                  ],
                ),
                // Item details - compact layout to prevent overflow
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.rating > 0) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.star,
                              size: 10,
                              color: item.rating >= 4.0
                                  ? Colors.green
                                  : AppTheme.primaryOrange,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: item.rating >= 4.0
                                    ? Colors.green
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '₹${item.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (item.hasDiscount) ...[
                            const SizedBox(width: 6),
                            Text(
                              '₹${item.originalPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build veg/non-veg indicator icon
  Widget _buildVegIndicator(bool isVeg) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border.all(
          color: isVeg ? Colors.green : Colors.red,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Icon(
        Icons.circle,
        size: 7,
        color: isVeg ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildItemPlaceholder() {
    return Container(
      color: AppTheme.primaryOrange.withOpacity(0.05),
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          color: AppTheme.primaryOrange.withOpacity(0.2),
          size: 40,
        ),
      ),
    );
  }

  /// Placeholder for loading state
  Widget _buildTrendingItemPlaceholder() {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12, width: 80),
                SizedBox(height: 4),
                SizedBox(height: 14, width: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenView(UserModel? userData) {
    return KitchenView(shopId: userData?.shopId);
  }

  Widget _buildDeliveryView(UserModel? userData) {
    return DeliveryView(shopId: userData?.shopId, shopIds: userData?.shopIds);
  }

  Widget _buildDeliveryDashboardView(UserModel? userData) {
    return DeliveryDashboardView(
      shopId: userData?.shopId,
      shopIds: userData?.shopIds,
    );
  }

  Widget _buildDashboardView(UserModel? userData) {
    return DashboardView(shopId: userData?.shopId);
  }

  Widget _buildDevPanel() {
    return const DeveloperPanel();
  }

  void _showProfileModal(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),

            if (authProvider.isAuthenticated) ...[
              // Animated Profile Icon
              // Profile Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child:
                      authProvider.userData?.photoURL != null &&
                          authProvider.userData!.photoURL!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: authProvider.userData!.photoURL!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              _buildLottieProfile(),
                        )
                      : _buildLottieProfile(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                authProvider.userData?.displayName ??
                    authProvider.userData?.email ??
                    '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                authProvider.userData?.email ?? '',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  authProvider.userData?.role.value.toUpperCase() ?? 'CUSTOMER',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // My Orders Tile
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  title: const Text(
                    'My Orders',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Track your active and past orders'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderHistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close modal first
                    await authProvider.signOut();
                    if (mounted) {
                      setState(() {
                        _selectedViewIndex = 0; // Reset to Customer view
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Signed out successfully'),
                          backgroundColor: AppTheme.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Sign Out'),
                ),
              ),
            ] else ...[
              // Login prompt
              const Icon(
                Icons.account_circle_outlined,
                size: 64,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome, Guest!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to track your orders and get personalized recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Continue as Guest'),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(UserModel? userData) {
    return Center(
      child: Text(
        userData?.initials ?? 'G',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryOrange,
        ),
      ),
    );
  }

  Widget _buildLottieProfile() {
    return Container(
      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
      child: Center(
        child: Lottie.network(
          LottieAssets.profile,
          width: 80,
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(
            Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).userData?.initials ??
                'U',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: BottomNavigationBar(
            currentIndex: _customerTabIndex,
            onTap: (index) {
              setState(() {
                _customerTabIndex = index;
              });
            },
            elevation: 0,
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryOrange,
            unselectedItemColor: AppTheme.textSecondary,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // User Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryOrange.withOpacity(0.2),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: userData?.photoURL != null && userData!.photoURL!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: userData.photoURL!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryOrange),
                                ),
                                errorWidget: (context, url, error) => _buildLottieProfile(),
                              )
                            : _buildLottieProfile(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userData?.displayName ?? userData?.email.split('@').first ?? 'Guest User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userData?.email ?? 'Sign in to sync your data',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (userData != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          userData.role.value.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions Card
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (userData != null) ...[
                      _buildProfileTile(
                        icon: Icons.receipt_long_rounded,
                        title: 'My Orders',
                        subtitle: 'Check history and tracking status',
                        onTap: () {
                          setState(() {
                            _customerTabIndex = 2; // Jump to Orders tab
                          });
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                    ],
                    _buildProfileTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification Settings',
                      subtitle: 'Manage alerts and messages',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'Get help or report issues',
                      onTap: () {
                        // Show help dialog or screen
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action button (Sign Out / Sign In)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (userData != null) {
                      await authProvider.signOut();
                      setState(() {
                        _selectedViewIndex = 0;
                        _customerTabIndex = 0;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signed out successfully'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: userData != null ? AppTheme.error : AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(userData != null ? 'Sign Out' : 'Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: AppTheme.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
