import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../models/cash_transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/animations.dart';

class DashboardView extends StatefulWidget {
  final String? shopId;

  const DashboardView({super.key, this.shopId});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final OrderService _orderService = OrderService();

  String _historyFilter = 'week';
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopId = widget.shopId ?? authProvider.userData?.shopId;

    if (shopId != null) {
      final stats = await _orderService.getOrderStats(shopId);
      if (mounted) {
        setState(() => _stats = stats);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;
    final isDeveloper = userData?.role == UserRole.developer;

    // STRICT ROLE-BASED FILTERING: Non-developers are locked to their assigned shop
    final activeShopId = isDeveloper
        ? (widget.shopId ?? userData?.shopId)
        : userData?.shopId;

    if (activeShopId == null && !isDeveloper) {
      return const Center(
        child: EmptyState(
          title: 'No Shop Assigned',
          subtitle: 'You need to be assigned to a shop to view the dashboard.',
          animationType: 'box',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(activeShopId, isDeveloper),
            const SizedBox(height: 24),

            // KPI Cards
            _buildKPICards(),
            const SizedBox(height: 24),

            // Returned Orders (Critical Losses)
            if (activeShopId != null) ...[
              _buildReturnedOrders(activeShopId),
              const SizedBox(height: 24),
            ],

            // Charts Row
            _buildChartsRow(),
            const SizedBox(height: 24),

            // Order History
            _buildOrderHistory(activeShopId),
            const SizedBox(height: 24),

            // Cash Management (Owner Settlement)
            if (activeShopId != null) ...[
              _buildCashManagement(activeShopId),
              const SizedBox(height: 24),
            ],

            // Staff Management
            _buildStaffManagement(activeShopId),
            const SizedBox(height: 24),

            // Shop Settings (Order Queue Toggle)
            if (activeShopId != null) _buildShopSettings(activeShopId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String? shopId, bool isDeveloper) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDeveloper && shopId == null
              ? 'Global Dashboard'
              : 'Owner Dashboard',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(
          isDeveloper && shopId == null
              ? 'Monitoring performance across all shops (Global View).'
              : 'A high-level overview of your kitchen\'s performance.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildKPICards() {
    return Row(
      children: [
        Expanded(
          child: _KPICard(
            title: 'Total Revenue',
            value: '₹${(_stats?['totalRevenue'] ?? 0).toStringAsFixed(0)}',
            icon: Icons.currency_rupee,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KPICard(
            title: 'Total Orders',
            value: '${_stats?['totalOrders'] ?? 0}',
            icon: Icons.receipt_long,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KPICard(
            title: 'Avg. Order',
            value: '₹${(_stats?['avgOrderValue'] ?? 0).toStringAsFixed(0)}',
            icon: Icons.analytics,
            color: AppTheme.ownerColor,
          ),
        ),
      ],
    );
  }

  Widget _buildReturnedOrders(String shopId) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.getReturnedOrders(shopId),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_return, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Returned Orders (Loss)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${orders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'These orders were not delivered. Verify items are returned to stock.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const Divider(height: 24),
              ...orders.map((order) => _buildReturnedOrderTile(order)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReturnedOrderTile(OrderModel order) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Reason: ${order.returnReason ?? "No reason provided"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Text(
            order.formattedTotal,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _acknowledgeReturn(order),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  void _acknowledgeReturn(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge Return'),
        content: Text(
          'Acknowledge that Order ${order.orderNumber} items have been received back at the shop? This will move it to history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // We keep it as 'returned' but we could update some flag like 'acknowledgedByOwner'
                // For now, let's just mark it as 'cancelled' or just leave it.
                // The user said "this situation is very critical for loss of all".
                // Let's mark it as 'cancelled' so it leaves the red-alert list and goes to history.
                await _orderService.updateOrderStatus(
                  order.id,
                  OrderStatus.cancelled,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Return acknowledged.')),
                  );
                }
              } catch (e) {
                // ...
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistory(String? shopId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed Order History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          if (shopId == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Select a shop to view order history.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else ...[
            // Filters
            Row(
              children: [
                _FilterChip(
                  label: 'This Week',
                  isSelected: _historyFilter == 'week',
                  onTap: () => setState(() => _historyFilter = 'week'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'This Month',
                  isSelected: _historyFilter == 'month',
                  onTap: () => setState(() => _historyFilter = 'month'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'All Time',
                  isSelected: _historyFilter == 'all',
                  onTap: () => setState(() => _historyFilter = 'all'),
                ),
              ],
            ),
            const Divider(height: 32),

            // Orders list
            StreamBuilder<List<OrderModel>>(
              stream: _orderService.getCompletedOrders(shopId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AnimatedLoader(size: 80));
                }

                var orders = snapshot.data ?? [];

                // Filter by date
                if (_historyFilter == 'week') {
                  final weekAgo = DateTime.now().subtract(
                    const Duration(days: 7),
                  );
                  orders = orders
                      .where((o) => o.createdAt?.isAfter(weekAgo) ?? false)
                      .toList();
                } else if (_historyFilter == 'month') {
                  final monthAgo = DateTime.now().subtract(
                    const Duration(days: 30),
                  );
                  orders = orders
                      .where((o) => o.createdAt?.isAfter(monthAgo) ?? false)
                      .toList();
                }

                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: AppTheme.textTertiary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No completed orders yet.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length > 10 ? 10 : orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _CompletedOrderTile(order: order);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffManagement(String? shopId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staff Management',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Staff Member',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'staff@example.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      initialValue: 'kitchen',
                      items: const [
                        DropdownMenuItem(
                          value: 'kitchen',
                          child: Text('Kitchen Staff'),
                        ),
                        DropdownMenuItem(
                          value: 'delivery',
                          child: Text('Delivery Staff'),
                        ),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Staff management coming soon!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Add Staff'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Staff',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No staff members assigned yet.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashManagement(String shopId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cash Management',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.payments, size: 14, color: AppTheme.warning),
                    SizedBox(width: 4),
                    Text(
                      'Collection Mode',
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
          const SizedBox(height: 8),
          const Text(
            'Confirm and settle cash payments collected by your delivery team.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Summary Statistics
          StreamBuilder<List<CashTransactionModel>>(
            stream: _orderService.getCashTransactions(shopId: shopId),
            builder: (context, txSnapshot) {
              double collected = 0;
              double settled = 0;
              if (txSnapshot.hasData) {
                for (var tx in txSnapshot.data!) {
                  if (tx.type == CashTransactionType.collection) {
                    collected += tx.amount;
                  } else if (tx.type == CashTransactionType.settlement) {
                    settled += tx.amount;
                  }
                }
              }
              final outstanding = collected - settled;

              return Row(
                children: [
                  Expanded(
                    child: _CashSummaryCard(
                      label: 'Collected',
                      amount: collected,
                      color: AppTheme.success,
                      icon: Icons.add_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CashSummaryCard(
                      label: 'Settled',
                      amount: settled,
                      color: AppTheme.primaryBlue,
                      icon: Icons.handshake_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CashSummaryCard(
                      label: 'Outstanding',
                      amount: outstanding,
                      color: outstanding > 0
                          ? AppTheme.warning
                          : AppTheme.textSecondary,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(height: 32),
          StreamBuilder<List<OrderModel>>(
            stream: _orderService.getUnsettledCashOrders(shopId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No unsettled cash collections.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }

              return Column(
                children: orders
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order ${order.orderNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Collected by ${order.collectedBy ?? "Staff"}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              order.formattedTotal,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => _showSettlementConfirm(order),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: const Size(80, 36),
                              ),
                              child: const Text(
                                'Settle',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSettlementConfirm(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Settlement'),
        content: Text(
          'Confirm that you have received ${order.formattedTotal} in cash for Order ${order.orderNumber}?',
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
              try {
                await _orderService.settleCash(
                  order.id,
                  authProvider.user?.uid ?? 'unknown',
                  authProvider.userData?.displayName ?? 'Owner',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cash settled successfully!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
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
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsRow() {
    return Row(
      children: [
        Expanded(child: _buildWeeklySalesCard()),
        const SizedBox(width: 16),
        Expanded(child: _buildOrderStatusCard()),
      ],
    );
  }

  Widget _buildWeeklySalesCard() {
    // Get weekly sales data from stats
    final weeklySales =
        _stats?['weeklySales'] as List<double>? ?? List.generate(7, (_) => 0.0);
    final maxSale = weeklySales.isEmpty
        ? 1.0
        : (weeklySales.reduce((a, b) => a > b ? a : b));
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Sales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '₹${(_stats?['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = index < weeklySales.length
                    ? weeklySales[index]
                    : 0.0;
                final heightPercent = maxSale > 0 ? (value / maxSale) : 0.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (value > 0)
                      Text(
                        '₹${value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 8,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 20,
                      height: (heightPercent * 80).clamp(4, 80),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppTheme.primaryBlue.withOpacity(0.8),
                            AppTheme.primaryBlue.withOpacity(0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[index],
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusCard() {
    // Get order status counts
    final pending = _stats?['pending'] ?? 0;
    final preparing = _stats?['preparing'] ?? 0;
    final ready = _stats?['ready'] ?? 0;
    final delivered = _stats?['delivered'] ?? 0;
    final total = pending + preparing + ready + delivered;

    final statusData = [
      {'label': 'Pending', 'value': pending, 'color': Colors.orange},
      {'label': 'Preparing', 'value': preparing, 'color': Colors.blue},
      {'label': 'Ready', 'value': ready, 'color': Colors.green},
      {'label': 'Delivered', 'value': delivered, 'color': AppTheme.success},
    ];

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$total orders',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: statusData.map((data) {
                final value = data['value'] as int;
                final percent = total > 0 ? (value / total) : 0.0;

                return Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: data['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        data['label'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: data['color'] as Color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopSettings(String shopId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, size: 20),
              SizedBox(width: 8),
              Text(
                'Shop Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<ShopModel?>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .snapshots()
                .map((doc) => doc.exists ? ShopModel.fromFirestore(doc) : null),
            builder: (context, snapshot) {
              final shop = snapshot.data;
              final showQueue = shop?.showOrderQueue ?? false;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Show Order Queue to Customers',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              showQueue
                                  ? 'Customers can see how many orders are waiting'
                                  : 'Order queue is hidden from customers',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: showQueue,
                        onChanged: (value) async {
                          await FirebaseFirestore.instance
                              .collection('shops')
                              .doc(shopId)
                              .update({'showOrderQueue': value});
                        },
                        activeThumbColor: AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Show Estimated Waiting Time',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              shop?.showWaitTime ?? false
                                  ? 'Customers see an estimated preparation time'
                                  : 'Waiting time is hidden from customers',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: shop?.showWaitTime ?? false,
                        onChanged: (value) async {
                          await FirebaseFirestore.instance
                              .collection('shops')
                              .doc(shopId)
                              .update({'showWaitTime': value});
                        },
                        activeThumbColor: AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                  if (shop?.showWaitTime ?? false) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Avg. Prep Time per Order (mins)',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                onPressed: () async {
                                  final current = shop?.estimatedWaitTime ?? 15;
                                  if (current > 5) {
                                    await FirebaseFirestore.instance
                                        .collection('shops')
                                        .doc(shopId)
                                        .update({
                                          'estimatedWaitTime': current - 5,
                                        });
                                  }
                                },
                              ),
                              Text(
                                '${shop?.estimatedWaitTime ?? 15}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () async {
                                  final current = shop?.estimatedWaitTime ?? 15;
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .update({
                                        'estimatedWaitTime': current + 5,
                                      });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ========== ORDER PRICING SETTINGS ==========
                  const Divider(height: 32),
                  const Row(
                    children: [
                      Icon(
                        Icons.currency_rupee,
                        size: 18,
                        color: AppTheme.success,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Order Pricing',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Minimum Order Amount
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Minimum Order Amount',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Orders below this amount won\'t be accepted',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: () async {
                                final current = shop?.minimumOrderAmount ?? 0;
                                if (current >= 50) {
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .update({
                                        'minimumOrderAmount': current - 50,
                                      });
                                }
                              },
                            ),
                            Text(
                              '₹${(shop?.minimumOrderAmount ?? 0).toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () async {
                                final current = shop?.minimumOrderAmount ?? 0;
                                if (current < 1000) {
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .update({
                                        'minimumOrderAmount': current + 50,
                                      });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Delivery Charge
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery Charge',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Fee added to each order',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: () async {
                                final current = shop?.deliveryCharge ?? 0;
                                if (current >= 10) {
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .update({'deliveryCharge': current - 10});
                                }
                              },
                            ),
                            Text(
                              '₹${(shop?.deliveryCharge ?? 0).toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () async {
                                final current = shop?.deliveryCharge ?? 0;
                                if (current < 200) {
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .update({'deliveryCharge': current + 10});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // GST Percentage
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GST Percentage',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Tax applied on food items',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: () async {
                                final current = shop?.gstPercentage ?? 5;
                                if (current >= 1) {
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .update({'gstPercentage': current - 1});
                                }
                              },
                            ),
                            Text(
                              '${(shop?.gstPercentage ?? 5).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () async {
                                final current = shop?.gstPercentage ?? 5;
                                if (current < 18) {
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .update({'gstPercentage': current + 1});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CompletedOrderTile extends StatelessWidget {
  final OrderModel order;

  const _CompletedOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppTheme.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  order.itemsSummary,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.formattedTotal,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                order.timeAgo,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashSummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _CashSummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
