import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
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
    final shopId = widget.shopId ?? userData?.shopId;
    final isDeveloper = userData?.role == UserRole.developer;

    if (shopId == null && !isDeveloper) {
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
            _buildHeader(),
            const SizedBox(height: 24),

            // KPI Cards
            _buildKPICards(),
            const SizedBox(height: 24),

            // Charts Row
            _buildChartsRow(),
            const SizedBox(height: 24),

            // Order History
            _buildOrderHistory(shopId),
            const SizedBox(height: 24),

            // Staff Management
            _buildStaffManagement(shopId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Owner Dashboard',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'A high-level overview of your kitchen\'s performance.',
          style: TextStyle(color: AppTheme.textSecondary),
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
                      value: 'kitchen',
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

  Widget _buildChartsRow() {
    return Row(
      children: [
        Expanded(child: _buildChartCard('Weekly Sales', Icons.show_chart)),
        const SizedBox(width: 16),
        Expanded(
          child: _buildChartCard('Order Status', Icons.pie_chart_outline),
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, IconData icon) {
    return Container(
      height: 200,
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
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Icon(icon, size: 20, color: AppTheme.textTertiary),
            ],
          ),
          const Spacer(),
          // Placeholder for actual chart
          Center(
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.05),
                    AppTheme.primaryBlue.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                painter: _ChartPlaceholderPainter(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  isPie: icon == Icons.pie_chart_outline,
                ),
              ),
            ),
          ),
          const Spacer(),
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

class _ChartPlaceholderPainter extends CustomPainter {
  final Color color;
  final bool isPie;

  _ChartPlaceholderPainter({required this.color, this.isPie = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (isPie) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.height / 2.5;
      canvas.drawCircle(center, radius, paint);
      canvas.drawLine(
        center,
        center + Offset(radius * 0.7, -radius * 0.7),
        paint,
      );
      canvas.drawLine(center, center + Offset(0, radius), paint);
    } else {
      final path = Path();
      path.moveTo(0, size.height * 0.8);
      path.quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.2,
        size.width * 0.4,
        size.height * 0.6,
      );
      path.quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.9,
        size.width * 0.8,
        size.height * 0.3,
      );
      path.lineTo(size.width, size.height * 0.5);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
