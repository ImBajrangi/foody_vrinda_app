import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll2;
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/shop_model.dart';
import '../../services/order_service.dart';
import '../../services/shop_service.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/animations.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _showConfetti = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showConfetti = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Order Status'),
        backgroundColor: AppTheme.cardBackground,
      ),
      body: Stack(
        children: [
          StreamBuilder<OrderModel?>(
            stream: orderService.orderStream(widget.orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: AnimatedLoader(message: 'Loading order...'),
                );
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final order = snapshot.data;

              if (order == null) {
                return const EmptyState(
                  title: 'Order not found',
                  subtitle: 'This order may have been cancelled or deleted.',
                  animationType: 'box',
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    StreamBuilder<ShopModel?>(
                      stream: ShopService().shopStream(order.shopId),
                      builder: (context, shopSnapshot) {
                        final shop = shopSnapshot.data;
                        final isCompleted =
                            order.status == OrderStatus.completed;
                        final isCancelled =
                            order.status == OrderStatus.cancelled;
                        final isReturned = order.status == OrderStatus.returned;

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground,
                                borderRadius: BorderRadius.circular(24),
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
                                  if (order.isUnreachable &&
                                      !isCompleted &&
                                      !isCancelled &&
                                      !isReturned)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.error.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_missed,
                                            color: AppTheme.error,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'DELIVERY PARTNER UNABLE TO REACH YOU',
                                                  style: TextStyle(
                                                    color: AppTheme.error,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                Text(
                                                  'We tried calling you ${order.contactAttempts.length} times. Please check your phone or your order may be returned to the shop.',
                                                  style: const TextStyle(
                                                    color: AppTheme.error,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            order.statusMessage,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isCompleted
                                                ? 'Delivered at ${order.arrivalTime}'
                                                : (isReturned
                                                      ? 'Returned at ${order.returnedAt != null ? DateFormat('hh:mm a').format(order.returnedAt!) : 'N/A'}'
                                                      : 'Estimated Arrival: ${_calculateETA(order, shop)}'),
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isCompleted &&
                                          !isCancelled &&
                                          !isReturned)
                                        const OrderStatusAnimation(
                                          status: 'status_tracking',
                                          size: 60,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  OrderStatusAnimation(
                                    status: order.status.value,
                                    size: 140,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    order.statusDetails,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  OrderTimeline(currentStatus: order.status),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Shop Contact Card
                            if (shop != null &&
                                !isCompleted &&
                                !isCancelled &&
                                !isReturned)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.store,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                shop.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const Text(
                                                'Need help with your order?',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _callShop(shop.phoneNumber),
                                          icon: const Icon(
                                            Icons.phone,
                                            size: 16,
                                          ),
                                          label: const Text('Call'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryBlue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isReturned &&
                                        shop.phoneNumber != null) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _openWhatsApp(shop.phoneNumber!),
                                          icon: const Icon(
                                            Icons.videocam,
                                            size: 20,
                                          ),
                                          label: const Text(
                                            'Video Call Support',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.primaryBlue,
                                            side: const BorderSide(
                                              color: AppTheme.primaryBlue,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Order Info Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildSimpleCard(
                            'Payment Method',
                            order.paymentMethod == PaymentMethod.cash
                                ? 'Cash on Delivery'
                                : 'Paid Online',
                            order.paymentMethod == PaymentMethod.cash
                                ? Icons.payments_outlined
                                : Icons.account_balance_wallet_outlined,
                            color: order.paymentMethod == PaymentMethod.cash
                                ? AppTheme.warning
                                : AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSimpleCard(
                            'Order Total',
                            order.formattedTotal,
                            Icons.receipt_long_outlined,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (order.paymentMethod == PaymentMethod.cash)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: order.cashStatus == CashStatus.collected
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              order.cashStatus == CashStatus.collected
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: order.cashStatus == CashStatus.collected
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.cashStatus == CashStatus.collected
                                        ? 'Payment Collected'
                                        : 'Payment Pending',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          order.cashStatus ==
                                              CashStatus.collected
                                          ? AppTheme.success
                                          : AppTheme.warning,
                                    ),
                                  ),
                                  Text(
                                    order.cashStatus == CashStatus.collected
                                        ? 'Your cash payment has been received by our delivery partner.'
                                        : 'Please have ${order.formattedTotal} ready to pay when your order arrives.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          (order.cashStatus ==
                                                      CashStatus.collected
                                                  ? AppTheme.success
                                                  : AppTheme.warning)
                                              .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Delivery info
                    Container(
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
                              Icon(
                                Icons.local_shipping,
                                color: AppTheme.success,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delivery Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          _buildInfoRow(
                            Icons.person_outline,
                            order.customerName,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.phone_outlined,
                            order.customerPhone,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            order.deliveryAddress,
                          ),
                        ],
                      ),
                    ),

                    // Delivery Map (if location available)
                    if (order.customerLatitude != null &&
                        order.customerLongitude != null)
                      _buildDeliveryMap(order),

                    const SizedBox(height: 24),

                    // Order items summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Items in Order',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Divider(height: 24),
                          ...order.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Text(
                                    '${item.quantity}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(item.name)),
                                  Text(item.formattedTotal),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Back to home button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Back to Home'),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),

          // Confetti overlay
          if (_showConfetti) const Positioned.fill(child: CelebrationOverlay()),
        ],
      ),
    );
  }

  Widget _buildSimpleCard(
    String label,
    String value,
    IconData icon, {
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Future<void> _callShop(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')),
        );
      }
      return;
    }

    // Clean phone number: remove spaces and non-digit characters except +
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try to launch anyway (canLaunchUrl can be unreliable)
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch dialer: $e')));
      }
    }
  }

  Widget _buildDeliveryMap(OrderModel order) {
    final ll2.LatLng position = ll2.LatLng(
      order.customerLatitude!,
      order.customerLongitude!,
    );

    return Container(
      height: 200,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppTheme.primaryBlue,
                ),
                SizedBox(width: 8),
                Text(
                  'Delivery Destination',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: position,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none, // Lite mode equivalent
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.foody.vrinda.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: position,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.error.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    String formattedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+91$formattedPhone';
    }
    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _calculateETA(OrderModel order, ShopModel? shop) {
    // ... (rest of the file)
    if (order.status == OrderStatus.completed) return 'Delivered';
    if (order.status == OrderStatus.cancelled) return 'N/A';

    final prepTime = shop?.estimatedWaitTime ?? 15;
    final deliveryTime = 15; // Assumption for delivery

    DateTime eta;
    if (order.createdAt != null) {
      eta = order.createdAt!.add(Duration(minutes: prepTime + deliveryTime));
    } else {
      eta = DateTime.now().add(Duration(minutes: prepTime + deliveryTime));
    }

    return DateFormat('hh:mm a').format(eta);
  }
}
