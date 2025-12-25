import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../services/shop_service.dart';
import '../../widgets/cards.dart';
import '../menu/menu_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ShopService _shopService = ShopService();
  int _selectedViewIndex =
      0; // 0: Customer, 1: Kitchen, 2: Delivery, 3: Dashboard, 4: Dev

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
            // Header
            _buildHeader(context, authProvider, userData),

            // View Switcher
            if (role != UserRole.customer) _buildViewSwitcher(role),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthProvider authProvider,
    UserModel? userData,
  ) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    'https://imbajrangi.github.io/Company/Vrindopnishad%20Web/class/logo/foodyVrinda-logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foody Vrinda',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Find your favorites',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Cart badge (for customers)
              if (_selectedViewIndex == 0 && cartProvider.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      IconButton(
                        onPressed: () {
                          // Show cart
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            cartProvider.totalItems.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Notification bell
              IconButton(
                onPressed: () {
                  // Show notifications
                },
                icon: const Icon(Icons.notifications_outlined),
              ),

              // Profile
              GestureDetector(
                onTap: () => _showProfileModal(context, authProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: userData?.photoURL != null
                            ? ClipOval(
                                child: Image.network(
                                  userData!.photoURL!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Text(
                                  userData?.initials ?? 'G',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        authProvider.isAuthenticated && userData != null
                            ? (userData.displayName ??
                                  userData.email.split('@').first)
                            : 'Guest',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher(UserRole role) {
    final views = <Map<String, dynamic>>[
      {'name': 'Order', 'icon': Icons.shopping_cart},
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

    if (role == UserRole.owner || role == UserRole.developer) {
      views.add({
        'name': 'Dashboard',
        'icon': Icons.dashboard,
        'color': AppTheme.ownerColor,
      });
    }

    if (role == UserRole.developer) {
      views.add({
        'name': 'Dev Panel',
        'icon': Icons.code,
        'color': AppTheme.developerColor,
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: List.generate(views.length, (index) {
              final view = views[index];
              final isSelected = _selectedViewIndex == index;
              final color = view['color'] as Color? ?? AppTheme.primaryBlue;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedViewIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
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
                      const SizedBox(width: 6),
                      Text(
                        view['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
    switch (_selectedViewIndex) {
      case 0:
        return _buildCustomerView();
      case 1:
        return _buildKitchenView();
      case 2:
        return _buildDeliveryView();
      case 3:
        return _buildDashboardView();
      case 4:
        return _buildDevPanel();
      default:
        return _buildCustomerView();
    }
  }

  Widget _buildCustomerView() {
    return StreamBuilder<List<ShopModel>>(
      stream: _shopService.getShops(),
      builder: (context, snapshot) {
        // Debug logging
        print('HomeScreen: ConnectionState = ${snapshot.connectionState}');
        print('HomeScreen: hasData = ${snapshot.hasData}');
        print('HomeScreen: hasError = ${snapshot.hasError}');
        if (snapshot.hasError) {
          print('HomeScreen: Error = ${snapshot.error}');
        }
        if (snapshot.hasData) {
          print('HomeScreen: Shops count = ${snapshot.data?.length}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryBlue),
                SizedBox(height: 16),
                Text(
                  'Loading shops...',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
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

        final shops = snapshot.data ?? [];

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
                    color: AppTheme.textTertiary.withValues(alpha: 0.5),
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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Shop Now 🍽️',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 4),
            Text(
              "Choose where you'd like to order from.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // Shop list
            ...shops.map(
              (shop) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ShopCard(
                  name: shop.name,
                  address: shop.address,
                  imageUrl: shop.imageUrl,
                  isOpen: shop.isOpen,
                  schedule: shop.schedule.displaySchedule,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuScreen(shop: shop),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKitchenView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.kitchen, size: 64, color: AppTheme.textTertiary),
          SizedBox(height: 16),
          Text(
            'Kitchen View',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Manage pending orders for your shop',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 64, color: AppTheme.textTertiary),
          SizedBox(height: 16),
          Text(
            'Delivery View',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Ready for delivery from your shop',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard, size: 64, color: AppTheme.ownerColor),
          SizedBox(height: 16),
          Text(
            'Owner Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Overview of your kitchen\'s performance',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDevPanel() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code, size: 64, color: AppTheme.developerColor),
          SizedBox(height: 16),
          Text(
            'Developer Panel',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'System testing & debugging',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
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
              // User info
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    authProvider.userData?.initials ?? 'U',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
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
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  authProvider.userData?.role.value.toUpperCase() ?? 'CUSTOMER',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    authProvider.signOut();
                    Navigator.pop(context);
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
                    backgroundColor: AppTheme.primaryBlue,
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
}
