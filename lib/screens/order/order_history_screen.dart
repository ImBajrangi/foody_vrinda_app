import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/animations.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.userData?.uid;
    final orderService = OrderService();

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: const Center(
          child: EmptyState(
            title: 'Login Required',
            subtitle: 'Please sign in to view your order history.',
            animationType: 'box',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: orderService.getUserOrders(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: AnimatedLoader(message: 'Loading your orders...'),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'No Orders Yet',
                subtitle:
                    'Your order history will appear here once you place an order.',
                animationType: 'box',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OrderSummaryCard(
                  order: order,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OrderTrackingScreen(orderId: order.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
