import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';

/// Order status tag widget
class OrderStatusTag extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusTag({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor(), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _getColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              color: _getColor(),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case OrderStatus.newOrder:
        return AppTheme.warning;
      case OrderStatus.preparing:
        return AppTheme.primaryBlue;
      case OrderStatus.readyForPickup:
        return AppTheme.success;
      case OrderStatus.outForDelivery:
        return AppTheme.ownerColor;
      case OrderStatus.completed:
        return AppTheme.success;
      case OrderStatus.cancelled:
        return AppTheme.error;
      case OrderStatus.returned:
        return Colors.deepPurple;
    }
  }
}

/// Order timeline widget
class OrderTimeline extends StatelessWidget {
  final OrderStatus currentStatus;

  const OrderTimeline({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final statuses = [
      OrderStatus.newOrder,
      OrderStatus.preparing,
      OrderStatus.readyForPickup,
      OrderStatus.outForDelivery,
      OrderStatus.completed,
    ];

    final currentIndex = statuses.indexOf(currentStatus);

    return Row(
      children: List.generate(statuses.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = (index - 1) ~/ 2;
          final isCompleted = stepIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 3,
              color: isCompleted ? AppTheme.success : AppTheme.border,
            ),
          );
        } else {
          // Step circle
          final stepIndex = index ~/ 2;
          final status = statuses[stepIndex];
          final isCompleted = stepIndex <= currentIndex;
          final isCurrent = stepIndex == currentIndex;

          return _TimelineStep(
            icon: _getIcon(status),
            label: status.displayName,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
          );
        }
      }),
    );
  }

  IconData _getIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.newOrder:
        return Icons.receipt_long;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.readyForPickup:
        return Icons.inventory_2;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.returned:
        return Icons.keyboard_return;
    }
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCompleted;
  final bool isCurrent;

  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? AppTheme.success : AppTheme.textTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCurrent ? 44 : 36,
          height: isCurrent ? 44 : 36,
          decoration: BoxDecoration(
            color: isCompleted
                ? color.withValues(alpha: 0.1)
                : AppTheme.background,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isCurrent ? 2 : 1),
          ),
          child: Icon(icon, color: color, size: isCurrent ? 22 : 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Order summary card
class OrderSummaryCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderSummaryCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.itemsSummary,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.primaryBlue,
                      ),
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
              ],
            ),
            const SizedBox(height: 12),
            OrderStatusTag(status: order.status),
          ],
        ),
      ),
    );
  }
}

/// Order items list
class OrderItemsList extends StatelessWidget {
  final List<OrderItem> items;

  const OrderItemsList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
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
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    item.formattedTotal,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
