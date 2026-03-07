import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/shop_service.dart';
import '../../services/notification_service.dart';
import '../../services/delivery_alarm_service.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/animations.dart';

class DeliveryView extends StatefulWidget {
  final String? shopId;
  final List<String>? shopIds;

  const DeliveryView({super.key, this.shopId, this.shopIds});

  @override
  State<DeliveryView> createState() => _DeliveryViewState();
}

class _DeliveryViewState extends State<DeliveryView> {
  final OrderService _orderService = OrderService();
  final ShopService _shopService = ShopService();
  final NotificationService _notificationService = NotificationService();
  String? _selectedShopId;
  final bool _showAllShops =
      false; // Changed to false by default for strict filtering
  Set<String> _previousOrderIds = {};
  bool _isFirstLoad = true;
  bool _isOnline = true; // Delivery availability status
  bool _isTogglingStatus = false;
  late Stream<List<ShopModel>> _shopsStream;

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.shopId;
    _shopsStream = _shopService.getShops();
    _initNotifications();
    _initAlarmListener();
  }

  void _initAlarmListener() {
    DeliveryAlarmService().addListener(_onAlarmStateChanged);
  }

  void _onAlarmStateChanged() {
    if (mounted) setState(() {});
  }

  bool get _isAlarmActive => DeliveryAlarmService().isAlarmActive;
  int get _unacknowledgedCount => DeliveryAlarmService().unacknowledgedCount;

  @override
  void dispose() {
    DeliveryAlarmService().removeListener(_onAlarmStateChanged);
    super.dispose();
  }

  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
  }

  /// Toggle online/offline status for delivery staff
  Future<void> _toggleOnlineStatus(bool value) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null) return;

    setState(() => _isTogglingStatus = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isOnline': value,
      });
      setState(() => _isOnline = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(value ? Icons.wifi : Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 8),
                Text(value ? 'You are now online' : 'You are now offline'),
              ],
            ),
            backgroundColor: value ? AppTheme.success : AppTheme.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  /// Check for new orders and show notifications
  void _checkForNewOrders(List<OrderModel> orders) {
    if (_isFirstLoad) {
      // On first load, just record existing order IDs
      _previousOrderIds = orders.map((o) => o.id).toSet();
      _isFirstLoad = false;
      return;
    }

    final currentOrderIds = orders.map((o) => o.id).toSet();
    final newOrderIds = currentOrderIds.difference(_previousOrderIds);

    // Show notification and trigger alarm for each new order
    for (final orderId in newOrderIds) {
      final order = orders.firstWhere((o) => o.id == orderId);
      _notificationService.showReadyForDeliveryNotification(
        orderId: order.id,
        customerName: order.customerName,
        address: order.deliveryAddress,
      );
      // Trigger alarm for delivery personnel
      DeliveryAlarmService().triggerAlarm(orderId);
    }

    _previousOrderIds = currentOrderIds;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;

    // Get shop ID(s)
    String? shopId = widget.shopId ?? userData?.shopId;
    List<String>? shopIds = widget.shopIds ?? userData?.shopIds;
    final isDeveloper = userData?.role == UserRole.developer;
    final isDelivery = userData?.role == UserRole.delivery;

    if (isDeveloper) {
      if (_showAllShops || _selectedShopId == null) {
        return _buildAllShopsDelivery(userData, isDeveloper);
      } else {
        return _buildSingleShopDelivery(_selectedShopId, userData, isDeveloper);
      }
    } else if (isDelivery) {
      if (shopIds != null && shopIds.isNotEmpty) {
        return _buildMultiShopDelivery(shopIds, userData, isDeveloper);
      } else if (shopId != null) {
        return _buildSingleShopDelivery(shopId, userData, isDeveloper);
      }
    }

    // Fallback for owners or other roles
    if (shopId != null) {
      return _buildSingleShopDelivery(shopId, userData, isDeveloper);
    }

    return const Center(
      child: EmptyState(
        title: 'No Shop Assigned',
        subtitle: 'You are not assigned to any shop for deliveries.',
        animationType: 'box',
      ),
    );
  }

  Widget _buildAllShopsDelivery(UserModel? userData, bool isDeveloper) {
    return Column(
      children: [
        _buildHeader(userData, isDeveloper),
        if (_isAlarmActive) _buildAlarmBanner(),
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _orderService.getDeliveryOrders(null), // null = all shops
            builder: (context, snapshot) => _buildOrdersList(snapshot),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleShopDelivery(
    String? shopId,
    UserModel? userData,
    bool isDeveloper,
  ) {
    return Column(
      children: [
        _buildHeader(userData, isDeveloper),
        if (_isAlarmActive) _buildAlarmBanner(),
        Expanded(
          child: shopId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Select a shop to view deliveries.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              : StreamBuilder<List<OrderModel>>(
                  stream: _orderService.getDeliveryOrders(shopId),
                  builder: (context, snapshot) => _buildOrdersList(snapshot),
                ),
        ),
      ],
    );
  }

  Widget _buildMultiShopDelivery(
    List<String> shopIds,
    UserModel? userData,
    bool isDeveloper,
  ) {
    return Column(
      children: [
        _buildHeader(userData, isDeveloper),
        if (_isAlarmActive) _buildAlarmBanner(),
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _orderService.getDeliveryOrdersMultiShop(shopIds),
            builder: (context, snapshot) => _buildOrdersList(snapshot),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(UserModel? userData, bool isDeveloper) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delivery_dining, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                StreamBuilder<List<ShopModel>>(
                  stream: _shopsStream,
                  builder: (context, snapshot) {
                    final shops = snapshot.data ?? [];
                    final shopName = isDeveloper && _selectedShopId == null
                        ? 'Global Delivery Monitor (All Shops)'
                        : (shops.any(
                                (s) =>
                                    s.id ==
                                    (isDeveloper
                                        ? _selectedShopId
                                        : (userData?.shopId ?? widget.shopId)),
                              )
                              ? shops
                                    .firstWhere(
                                      (s) =>
                                          s.id ==
                                          (isDeveloper
                                              ? _selectedShopId
                                              : (userData?.shopId ??
                                                    widget.shopId)),
                                    )
                                    .name
                              : 'My Shop');
                    return Text(
                      'Orders for $shopName',
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
          // Shop selector for developers
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.userData?.role == UserRole.developer) {
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
              // Availability toggle for delivery staff
              if (auth.userData?.role == UserRole.delivery) {
                return Row(
                  children: [
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: _isOnline
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isTogglingStatus
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: _isOnline,
                            onChanged: _toggleOnlineStatus,
                            activeThumbColor: AppTheme.success,
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

  Widget _buildOrdersList(AsyncSnapshot<List<OrderModel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: AnimatedLoader(message: 'Loading deliveries...'),
      );
    }

    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }

    final orders = snapshot.data ?? [];

    // Check for new orders and trigger notifications
    _checkForNewOrders(orders);

    if (orders.isEmpty) {
      return const EmptyState(
        title: 'No Deliveries',
        subtitle: 'Orders ready for delivery will appear here.',
        animationType: 'delivery',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _DeliveryOrderCard(
              order: order,
              onStatusUpdate: (status) => _updateOrderStatus(order.id, status),
            ),
          );
        },
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

  /// Builds the alarm banner for new delivery orders
  Widget _buildAlarmBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00B894), // Teal green for delivery
            const Color(0xFF00CEC9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B894).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0.15), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              // Delivery icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_unacknowledgedCount',
                            style: const TextStyle(
                              color: Color(0xFF00B894),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ready for Pickup!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Tap OK to acknowledge',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Acknowledge button
              GestureDetector(
                onTap: () => DeliveryAlarmService().acknowledgeAll(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFF00B894),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'OK',
                        style: TextStyle(
                          color: Color(0xFF2D3436),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
  }
}

class _DeliveryOrderCard extends StatelessWidget {
  final OrderModel order;
  final Function(OrderStatus) onStatusUpdate;

  const _DeliveryOrderCard({required this.order, required this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    final isReady = order.status == OrderStatus.readyForPickup;
    final isOutForDelivery = order.status == OrderStatus.outForDelivery;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: isReady
            ? Border.all(color: AppTheme.success, width: 2)
            : (order.paymentMethod == PaymentMethod.cash
                  ? Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null),
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
              color: isReady
                  ? AppTheme.success.withValues(alpha: 0.1)
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
                        if (order.totalAmount >= 500) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 10,
                                  color: AppTheme.warning,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Large',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warning,
                                  ),
                                ),
                              ],
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
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OrderStatusTag(status: order.status),
                    if (order.paymentMethod == PaymentMethod.cash)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments,
                              size: 12,
                              color: AppTheme.warning,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'CASH',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Customer & delivery info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer name
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          order.customerName.isNotEmpty
                              ? order.customerName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
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
                            order.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            order.customerPhone,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Call button
                    IconButton(
                      onPressed: () => _callCustomer(context, order),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: order.contactAttempts.length >= 3
                              ? Border.all(color: AppTheme.error, width: 2)
                              : null,
                        ),
                        child: Icon(
                          Icons.phone,
                          color: order.contactAttempts.length >= 3
                              ? AppTheme.error
                              : AppTheme.success,
                          size: 20,
                        ),
                      ),
                    ),
                    // WhatsApp button
                    IconButton(
                      onPressed: () => _openWhatsApp(order.customerPhone),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat,
                          color: Color(0xFF25D366),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                if (order.contactAttempts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 14,
                          color: order.contactAttempts.length >= 3
                              ? AppTheme.error
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Call attempts: ${order.contactAttempts.length} (Last: ${DateFormat('hh:mm a').format(order.contactAttempts.last)})',
                          style: TextStyle(
                            fontSize: 11,
                            color: order.contactAttempts.length >= 3
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                            fontWeight: order.contactAttempts.length >= 3
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Delivery address
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openMaps(
                          order.deliveryAddress,
                          lat: order.customerLatitude,
                          lng: order.customerLongitude,
                        ),
                        icon: const Icon(
                          Icons.directions,
                          color: AppTheme.primaryBlue,
                        ),
                        tooltip: 'Get directions',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Items summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.itemsSummary,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount to Collect',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.formattedTotal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppTheme.success,
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
                if (isReady) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          onStatusUpdate(OrderStatus.outForDelivery),
                      icon: const Icon(Icons.delivery_dining, size: 20),
                      label: const Text('Start Delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ] else if (isOutForDelivery) ...[
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (order.paymentMethod == PaymentMethod.cash) {
                          _showCashCollectionDialog(context, order);
                        } else {
                          onStatusUpdate(OrderStatus.completed);
                        }
                      },
                      icon: Icon(
                        order.paymentMethod == PaymentMethod.cash
                            ? Icons.payments
                            : Icons.check_circle,
                        size: 20,
                      ),
                      label: Text(
                        order.paymentMethod == PaymentMethod.cash
                            ? 'Collect Cash & Complete'
                            : 'Complete Delivery',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => _showReturnToShopDialog(context, order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Icon(Icons.assignment_return),
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

  Future<void> _callCustomer(BuildContext context, OrderModel order) async {
    final phoneNumber = order.customerPhone;
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available')),
      );
      return;
    }

    // Clean phone number: remove spaces and non-digit characters except +
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try anyway
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Log the attempt after calling
      try {
        await OrderService().logContactAttempt(order.id);
      } catch (e) {
        // Silently fail or log
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch dialer: $e')));
    }
  }

  Future<void> _openMaps(String address, {double? lat, double? lng}) async {
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      );
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    // Format phone number for WhatsApp (remove spaces/dashes, add country code if needed)
    String formattedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+91$formattedPhone'; // Default to India
    }
    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showCashCollectionDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cash Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please collect cash from customer:'),
            const SizedBox(height: 12),
            Text(
              order.formattedTotal,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confirm that you have received the exact amount.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final orderService = OrderService();

              try {
                await orderService.collectCash(
                  order.id,
                  authProvider.user?.uid ?? 'unknown',
                  authProvider.userData?.displayName ?? 'Delivery Partner',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cash collected and order completed!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Confirm Collection'),
          ),
        ],
      ),
    );
  }

  void _showReturnToShopDialog(BuildContext context, OrderModel order) {
    String reason = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_return, color: AppTheme.error),
            SizedBox(width: 12),
            Text('Return to Shop'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Critical: Failure to Deliver',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please provide a reason why this order is being returned to the shop:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (val) => reason = val,
              controller: TextEditingController(
                text: order.contactAttempts.length >= 3
                    ? 'Customer Unreachable (Tried ${order.contactAttempts.length} times)'
                    : '',
              ),
              decoration: InputDecoration(
                hintText: 'e.g., Customer Refused, No response at door',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            StreamBuilder<ShopModel?>(
              stream: ShopService().shopStream(order.shopId),
              builder: (context, snapshot) {
                final shop = snapshot.data;
                if (shop?.phoneNumber == null) return const SizedBox.shrink();
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openWhatsApp(shop!.phoneNumber!),
                    icon: const Icon(Icons.videocam, size: 20),
                    label: const Text('Video Call Shop for Assistance'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reason.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.pop(context);
              try {
                final orderService = OrderService();
                await orderService.markOrderAsReturned(order.id, reason.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order marked as Returned to Shop'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );
  }
}
