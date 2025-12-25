import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';

class StatusTag extends StatelessWidget {
  final String status;

  const StatusTag({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.getStatusBackgroundColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppTheme.getStatusDisplayName(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.getStatusTextColor(status),
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final String? shopName;
  final VoidCallback? onTap;
  final Widget? actionButton;

  const OrderCard({
    super.key,
    required this.order,
    this.shopName,
    this.onTap,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.timeAgo,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                StatusTag(status: order.status.value),
              ],
            ),

            const Divider(height: 24),

            // Customer info
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  order.customerPhone,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Items
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      item.formattedTotal,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 16),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  order.formattedTotal,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),

            // Action button
            if (actionButton != null) ...[
              const SizedBox(height: 16),
              actionButton!,
            ],

            // Test order badge
            if (order.isTestOrder) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.statusPreparing,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TEST ORDER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.statusPreparingText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OrderProgressTracker extends StatelessWidget {
  final OrderStatus currentStatus;

  const OrderProgressTracker({super.key, required this.currentStatus});

  int get _currentStep {
    switch (currentStatus) {
      case OrderStatus.newOrder:
        return 0;
      case OrderStatus.preparing:
        return 1;
      case OrderStatus.readyForPickup:
        return 2;
      case OrderStatus.outForDelivery:
        return 3;
      case OrderStatus.completed:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['New', 'Preparing', 'Ready', 'Delivery', 'Done'];

    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (index) {
            final isActive = index <= _currentStep;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppTheme.primaryBlue
                          : const Color(0xFFE0E0E0),
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: _currentStep / (steps.length - 1),
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(left: 24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
