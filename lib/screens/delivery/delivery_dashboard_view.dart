import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/cash_transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Dashboard view for delivery staff showing performance metrics
class DeliveryDashboardView extends StatefulWidget {
  final String? shopId;
  final List<String>? shopIds;

  const DeliveryDashboardView({super.key, this.shopId, this.shopIds});

  @override
  State<DeliveryDashboardView> createState() => _DeliveryDashboardViewState();
}

class _DeliveryDashboardViewState extends State<DeliveryDashboardView> {
  final OrderService _orderService = OrderService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String _selectedHistoryFilter = 'today'; // 'today', 'week', 'all'

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopId = widget.shopId ?? authProvider.userData?.shopId;

    final stats = await _orderService.getDeliveryStats(shopId);
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(userData),
            const SizedBox(height: 24),

            // Loading state
            if (_isLoading)
              const Center(child: AnimatedLoader(message: 'Loading stats...'))
            else ...[
              // Today's Stats
              _buildTodayStats(),
              const SizedBox(height: 20),

              // Location Hub
              _buildLocationPanel(),
              const SizedBox(height: 20),

              // Weekly Performance
              _buildWeeklyPerformance(),
              const SizedBox(height: 20),

              // All Time Stats
              _buildAllTimeStats(),
              const SizedBox(height: 20),

              // Cash Management Panel
              _buildCashPanel(userData?.uid),
              const SizedBox(height: 20),

              // Recent Deliveries
              _buildRecentDeliveries(),
              const SizedBox(height: 20),

              // Delivery History with Date Filters
              _buildDeliveryHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel? userData) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: userData?.photoURL != null && userData!.photoURL!.isNotEmpty
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      userData?.initials ?? 'D',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Welcome, ${userData?.displayName ?? 'Delivery Partner'}!',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Performance",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('dd MMM').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.check_circle,
                  label: 'Deliveries',
                  value: '${_stats?['todayDeliveries'] ?? 0}',
                  light: true,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.currency_rupee,
                  label: 'Collections',
                  value:
                      '₹${(_stats?['todayCollections'] ?? 0).toStringAsFixed(0)}',
                  light: true,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.pending_actions,
                  label: 'Active',
                  value: '${_stats?['activeOrders'] ?? 0}',
                  light: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlue.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Hub',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Navigate to shops & deliveries',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _LocationButton(
                  icon: Icons.store,
                  label: 'Shop',
                  color: AppTheme.success,
                  onTap: () => _openShopLocation(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LocationButton(
                  icon: Icons.location_on,
                  label: 'Orders',
                  color: AppTheme.error,
                  onTap: () => _openOrdersOnMap(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LocationButton(
                  icon: Icons.people,
                  label: 'Team',
                  color: AppTheme.primaryBlue,
                  onTap: () => _openTeamLocations(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openShopLocation() async {
    // Open shop location in Google Maps
    // TODO: Get actual shop coordinates from shop data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening shop location...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openOrdersOnMap() async {
    // Show all pending order destinations
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const _DeliveryMapView()),
    );
  }

  Future<void> _openTeamLocations() async {
    // Show other delivery boys' locations
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Team locations feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildWeeklyPerformance() {
    final weeklyDeliveries =
        _stats?['weeklyDeliveries'] as List<int>? ?? List.generate(7, (_) => 0);
    final maxDeliveries = weeklyDeliveries.isEmpty
        ? 1
        : weeklyDeliveries.reduce((a, b) => a > b ? a : b);
    final totalWeekly = weeklyDeliveries.fold<int>(0, (a, b) => a + b);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday - 1; // 0 = Monday

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Performance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalWeekly deliveries',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = index < weeklyDeliveries.length
                    ? weeklyDeliveries[index]
                    : 0;
                final heightPercent = maxDeliveries > 0
                    ? (value / maxDeliveries)
                    : 0.0;
                final isToday = index == today;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (value > 0)
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: (heightPercent * 60).clamp(4, 60),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isToday
                              ? [
                                  AppTheme.success,
                                  AppTheme.success.withValues(alpha: 0.6),
                                ]
                              : [
                                  AppTheme.primaryBlue.withValues(alpha: 0.7),
                                  AppTheme.primaryBlue.withValues(alpha: 0.3),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday
                            ? AppTheme.success
                            : AppTheme.textSecondary,
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

  Widget _buildAllTimeStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'All Time Stats',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AllTimeCard(
                  icon: Icons.local_shipping,
                  label: 'Total Deliveries',
                  value: '${_stats?['totalDeliveries'] ?? 0}',
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AllTimeCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Total Collections',
                  value:
                      '₹${(_stats?['totalCollections'] ?? 0).toStringAsFixed(0)}',
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDeliveries() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopId = widget.shopId ?? authProvider.userData?.shopId;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Deliveries',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<OrderModel>>(
            stream: shopId != null
                ? _orderService.getCompletedOrders(shopId)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snapshot.data ?? [];
              // Filter to today's orders
              final today = DateTime.now();
              final todayOrders = orders
                  .where((o) {
                    final orderDate = o.createdAt;
                    if (orderDate == null) return false;
                    return orderDate.day == today.day &&
                        orderDate.month == today.month &&
                        orderDate.year == today.year;
                  })
                  .take(5)
                  .toList();

              if (todayOrders.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No deliveries completed today yet',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: todayOrders
                    .map((order) => _RecentDeliveryTile(order: order))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryHistory() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopId = widget.shopId ?? authProvider.userData?.shopId;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Icon(Icons.history, color: AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          // Date filter chips
          Row(
            children: [
              _buildFilterChip('Today', 'today'),
              const SizedBox(width: 8),
              _buildFilterChip('This Week', 'week'),
              const SizedBox(width: 8),
              _buildFilterChip('All Time', 'all'),
            ],
          ),
          const SizedBox(height: 16),
          // History list
          StreamBuilder<List<OrderModel>>(
            stream: shopId != null
                ? _orderService.getCompletedOrders(shopId)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data ?? [];
              final filteredOrders = _filterOrdersByDate(orders);

              if (filteredOrders.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No deliveries for ${_getFilterLabel()}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // Summary row
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${filteredOrders.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppTheme.success,
                              ),
                            ),
                            const Text(
                              'Deliveries',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: AppTheme.border),
                        Column(
                          children: [
                            Text(
                              '₹${_calculateTotalCash(filteredOrders).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppTheme.warning,
                              ),
                            ),
                            const Text(
                              'Cash to Hand',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ...filteredOrders
                      .take(10)
                      .map((order) => _RecentDeliveryTile(order: order)),
                  if (filteredOrders.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${filteredOrders.length - 10} more deliveries',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedHistoryFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedHistoryFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  List<OrderModel> _filterOrdersByDate(List<OrderModel> orders) {
    final now = DateTime.now();
    switch (_selectedHistoryFilter) {
      case 'today':
        return orders.where((o) {
          if (o.createdAt == null) return false;
          return o.createdAt!.day == now.day &&
              o.createdAt!.month == now.month &&
              o.createdAt!.year == now.year;
        }).toList();
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return orders.where((o) {
          if (o.createdAt == null) return false;
          return o.createdAt!.isAfter(weekAgo);
        }).toList();
      case 'all':
      default:
        return orders;
    }
  }

  String _getFilterLabel() {
    switch (_selectedHistoryFilter) {
      case 'today':
        return 'today';
      case 'week':
        return 'this week';
      case 'all':
        return 'all time';
      default:
        return 'selected period';
    }
  }

  double _calculateTotalCash(List<OrderModel> orders) {
    return orders
        .where((o) => o.paymentMethod == PaymentMethod.cash)
        .fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  Widget _buildCashPanel(String? userId) {
    if (userId == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cash in Hand',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(
                Icons.account_balance_wallet,
                color: AppTheme.primaryBlue.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<CashTransactionModel>>(
            stream: _orderService.getCashTransactions(userId: userId),
            builder: (context, snapshot) {
              double collected = 0;
              double settled = 0;
              if (snapshot.hasData) {
                for (var tx in snapshot.data!) {
                  if (tx.type == CashTransactionType.collection) {
                    collected += tx.amount;
                  } else if (tx.type == CashTransactionType.settlement) {
                    settled += tx.amount;
                  }
                }
              }
              final pending = collected - settled;

              return Column(
                children: [
                  Row(
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pending > 0
                          ? AppTheme.warning.withValues(alpha: 0.1)
                          : AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pending > 0
                            ? AppTheme.warning.withValues(alpha: 0.2)
                            : AppTheme.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'PENDING SETTLEMENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${pending.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: pending > 0
                                ? AppTheme.warning
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool light;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : AppTheme.textPrimary;
    final subColor = light ? Colors.white70 : AppTheme.textSecondary;

    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: subColor)),
      ],
    );
  }
}

class _AllTimeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AllTimeCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RecentDeliveryTile extends StatelessWidget {
  final OrderModel order;

  const _RecentDeliveryTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  order.deliveryAddress,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (order.paymentMethod == PaymentMethod.cash
                                ? AppTheme.warning
                                : AppTheme.primaryBlue)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.paymentMethod == PaymentMethod.cash
                        ? 'CASH'
                        : 'ONLINE',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: order.paymentMethod == PaymentMethod.cash
                          ? AppTheme.warning
                          : AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.formattedTotal,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.success,
                ),
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

class _LocationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LocationButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryMapView extends StatefulWidget {
  const _DeliveryMapView();

  @override
  State<_DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<_DeliveryMapView> {
  final OrderService _orderService = OrderService();
  final MapController _mapController = MapController();
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopId = authProvider.userData?.shopId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Delivery Map'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'My Location',
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: shopId != null
            ? _orderService.getDeliveryOrders(shopId)
            : Stream.value([]),
        builder: (context, snapshot) {
          _updateMarkers(snapshot.data ?? []);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(28.6139, 77.2090),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.foody.vrinda.app',
                  ),
                  MarkerLayer(markers: _markers),
                ],
              ),
              // Legend
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(Colors.green, 'Ready'),
                      _buildLegendItem(Colors.orange, 'En Route'),
                      _buildLegendItem(Colors.blue, 'Shop'),
                    ],
                  ),
                ),
              ),
              // Order count
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delivery_dining,
                        color: AppTheme.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_markers.length} Orders',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _updateMarkers(List<OrderModel> orders) {
    final List<Marker> newMarkers = [];
    final shopLocation = const LatLng(28.6139, 77.2090);

    // Add shop marker
    newMarkers.add(
      Marker(
        point: shopLocation,
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 28),
        ),
      ),
    );

    // Add order destination markers
    for (var i = 0; i < orders.length; i++) {
      final order = orders[i];
      final isReady = order.status == OrderStatus.readyForPickup;
      final color = isReady ? Colors.green : Colors.orange;
      final icon = isReady ? Icons.location_on : Icons.delivery_dining;

      final hasLocation =
          order.customerLatitude != null && order.customerLongitude != null;

      final position = hasLocation
          ? LatLng(order.customerLatitude!, order.customerLongitude!)
          : LatLng(
              shopLocation.latitude + (i * 0.01) - 0.02,
              shopLocation.longitude + (i * 0.008) - 0.01,
            );

      newMarkers.add(
        Marker(
          point: position,
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () => _showOrderDetails(order),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      );
    }

    if (_markers.length != newMarkers.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _markers = newMarkers;
          });
          if (_markers.isNotEmpty) {
            _fitMarkers();
          }
        }
      });
    }
  }

  void _fitMarkers() {
    if (_markers.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(
      _markers.map((m) => m.point).toList(),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      order.customerName.isNotEmpty
                          ? order.customerName[0]
                          : 'C',
                      style: const TextStyle(
                        fontSize: 20,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        order.customerPhone,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  order.formattedTotal,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.deliveryAddress)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openNavigation(
                  order.deliveryAddress,
                  lat: order.customerLatitude,
                  lng: order.customerLongitude,
                ),
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNavigation(
    String address, {
    double? lat,
    double? lng,
  }) async {
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
    if (mounted) Navigator.pop(context);
  }

  Future<void> _goToCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      final position = await Geolocator.getCurrentPosition();
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
