import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/shop_service.dart';
import '../../services/order_notification_manager.dart';
import '../../services/notification_service.dart';
import '../../services/kitchen_alarm_service.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';

class KitchenView extends StatefulWidget {
  final String? shopId;

  const KitchenView({super.key, this.shopId});

  @override
  State<KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends State<KitchenView> {
  final OrderService _orderService = OrderService();
  final ShopService _shopService = ShopService();
  final OrderNotificationManager _notificationManager =
      OrderNotificationManager();
  final NotificationService _notificationService = NotificationService();
  final KitchenAlarmService _alarmService = KitchenAlarmService();
  String? _selectedShopId;
  bool _isAlarmActive = false;
  int _unacknowledgedCount = 0;
  late Stream<List<ShopModel>> _shopsStream;

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.shopId;
    _shopsStream = _shopService.getShops();
    _initNotificationListener();
    _initAlarmListener();
  }

  void _initAlarmListener() {
    // Initialize alarm service
    _alarmService.initialize();
    // Listen for alarm state changes
    _alarmService.addListener(_onAlarmStateChanged);
    // Set initial state
    _isAlarmActive = _alarmService.isAlarmActive;
    _unacknowledgedCount = _alarmService.unacknowledgedCount;
  }

  void _onAlarmStateChanged() {
    if (mounted) {
      setState(() {
        _isAlarmActive = _alarmService.isAlarmActive;
        _unacknowledgedCount = _alarmService.unacknowledgedCount;
      });
    }
  }

  Future<void> _initNotificationListener() async {
    // Get user data after first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userData = authProvider.userData;

      // Initialize notification service first
      await _notificationService.initialize();
      await _notificationService.requestPermissions();

      if (userData != null &&
          (userData.role == UserRole.owner ||
              userData.role == UserRole.kitchen ||
              userData.role == UserRole.developer)) {
        _notificationManager.startListening(
          userRole: userData.role,
          shopId: userData.shopId ?? widget.shopId,
        );
      }
    });
  }

  @override
  void dispose() {
    _alarmService.removeListener(_onAlarmStateChanged);
    _notificationManager.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;
    final isDeveloper = userData?.role == UserRole.developer;

    // Use selected shop or fall back to user's assigned shop
    // STRICT ROLE-BASED FILTERING: Non-developers are locked to their assigned shop
    final activeShopId = isDeveloper
        ? (_selectedShopId ?? userData?.shopId)
        : userData?.shopId;

    if (activeShopId == null && !isDeveloper) {
      return const Center(
        child: EmptyState(
          title: 'No Shop Assigned',
          subtitle: 'You are not assigned to any shop yet.',
          animationType: 'box',
        ),
      );
    }

    return Column(
      children: [
        // Alarm Banner - shows when new orders need acknowledgment
        if (_isAlarmActive) _buildAlarmBanner(),

        // Header
        _buildHeader(isDeveloper),

        // Orders list
        Expanded(
          child: activeShopId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Select a shop to view orders.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              : StreamBuilder<List<OrderModel>>(
                  stream: _orderService.getKitchenOrders(activeShopId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: AnimatedLoader(message: 'Loading orders...'),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final orders = snapshot.data ?? [];

                    if (orders.isEmpty) {
                      return const EmptyState(
                        title: 'No Pending Orders',
                        subtitle: 'All caught up! New orders will appear here.',
                        animationType: 'box',
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _KitchenOrderCard(
                              order: order,
                              onStatusUpdate: (status) =>
                                  _updateOrderStatus(order.id, status),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAlarmBanner() {
    return _AnimatedAlarmBanner(
      unacknowledgedCount: _unacknowledgedCount,
      onAcknowledge: () => _alarmService.acknowledgeAll(),
    );
  }

  Widget _buildHeader(bool isDeveloper) {
    final userData = Provider.of<AuthProvider>(context, listen: false).userData;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  userData?.photoURL != null && userData!.photoURL!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: userData.photoURL!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          userData.initials,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        userData?.initials ?? 'K',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitchen',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                StreamBuilder<List<ShopModel>>(
                  stream: _shopsStream,
                  builder: (context, snapshot) {
                    final shops = snapshot.data ?? [];
                    final shopName = _selectedShopId == null
                        ? 'All Shops'
                        : shops
                              .firstWhere(
                                (s) => s.id == _selectedShopId,
                                orElse: () =>
                                    ShopModel(id: '', name: 'Unknown Shop'),
                              )
                              .name;
                    return Text(
                      isDeveloper && _selectedShopId == null
                          ? 'Global Kitchen Monitor (All Shops)'
                          : 'Manage pending orders for $shopName',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Create order button (for owner/developer)
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final isDev = auth.userData?.role == UserRole.developer;
              final isOwner = auth.userData?.role == UserRole.owner;

              if (isDev) {
                return StreamBuilder<List<ShopModel>>(
                  stream: _shopsStream,
                  builder: (context, snapshot) {
                    final shops = snapshot.data ?? [];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedShopId,
                          hint: const Text('Select Shop'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Shops'),
                            ),
                            ...shops.map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedShopId = val);
                          },
                        ),
                      ),
                    );
                  },
                );
              }

              if (isOwner) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Create order coming soon!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _orderService.updateOrderStatus(orderId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated to ${status.displayName}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

/// Premium animated alarm banner inspired by Swiggy/Zomato
class _AnimatedAlarmBanner extends StatefulWidget {
  final int unacknowledgedCount;
  final VoidCallback onAcknowledge;

  const _AnimatedAlarmBanner({
    required this.unacknowledgedCount,
    required this.onAcknowledge,
  });

  @override
  State<_AnimatedAlarmBanner> createState() => _AnimatedAlarmBannerState();
}

class _AnimatedAlarmBannerState extends State<_AnimatedAlarmBanner>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bellController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bellAnimation;

  @override
  void initState() {
    super.initState();

    // Pulsing glow animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Bell shake animation
    _bellController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);

    _bellAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bellController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _bellAnimation]),
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B6B),
                const Color(0xFFEE5A5A),
                const Color(0xFFD63031),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFFF6B6B,
                ).withOpacity(0.5 * _pulseAnimation.value),
                blurRadius: 20 * _pulseAnimation.value,
                spreadRadius: 2 * _pulseAnimation.value,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Glassmorphism overlay
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.15), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  // Animated bell with glow
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(
                            0.3 * _pulseAnimation.value,
                          ),
                          blurRadius: 12 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: _bellAnimation.value,
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${widget.unacknowledgedCount}',
                                style: const TextStyle(
                                  color: Color(0xFFD63031),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'New Order${widget.unacknowledgedCount > 1 ? 's' : ''}!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: Colors.white.withOpacity(0.8),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Tap to acknowledge & stop alarm',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Premium acknowledge button
                  GestureDetector(
                    onTap: widget.onAcknowledge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: const Color(0xFF00B894),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'OK',
                            style: TextStyle(
                              color: Color(0xFF2D3436),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KitchenOrderCard extends StatelessWidget {
  final OrderModel order;
  final Function(OrderStatus) onStatusUpdate;

  const _KitchenOrderCard({required this.order, required this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: order.status == OrderStatus.newOrder
            ? Border.all(color: AppTheme.warning, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: order.status == OrderStatus.newOrder
                  ? AppTheme.warning.withValues(alpha: 0.1)
                  : AppTheme.primaryBlue.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (order.isTestOrder) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'TEST',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.timeAgo,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                OrderStatusTag(status: order.status),
              ],
            ),
          ),

          // Arrival Time & Importance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Arrival: ${order.arrivalTime}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: order.importanceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: order.importanceColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.priority_high,
                        size: 12,
                        color: order.importanceColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.importance,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: order.importanceColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${item.quantity}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Importance Basis (Total)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      order.formattedTotal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                if (order.status == OrderStatus.newOrder) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onStatusUpdate(OrderStatus.preparing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Start Preparing'),
                    ),
                  ),
                ] else if (order.status == OrderStatus.preparing) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          onStatusUpdate(OrderStatus.readyForPickup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Mark Ready'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
