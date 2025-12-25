import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/shop_service.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/animations.dart';

class KitchenView extends StatefulWidget {
  final String? shopId;

  const KitchenView({super.key, this.shopId});

  @override
  State<KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends State<KitchenView> {
  final OrderService _orderService = OrderService();
  final ShopService _shopService = ShopService();
  String? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.shopId;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;
    final isDeveloper = userData?.role == UserRole.developer;

    // Use selected shop or fall back to user's assigned shop
    final activeShopId = _selectedShopId ?? userData?.shopId;

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
        // Header
        _buildHeader(),

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

  Widget _buildHeader() {
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
            child: const Icon(Icons.kitchen, color: Colors.white),
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
                  stream: _shopService.getShops(),
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
                      'Manage pending orders for $shopName',
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
                  stream: _shopService.getShops(),
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
                return ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Show create order dialog
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (order.isTestOrder)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warning,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'TEST',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.timeAgo,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                OrderStatusTag(status: order.status),
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
                        Expanded(child: Text(item.name)),
                        Text(
                          item.formattedTotal,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),

                // Customer info
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(order.customerPhone),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(order.deliveryAddress)),
                  ],
                ),

                const SizedBox(height: 16),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.formattedTotal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
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
