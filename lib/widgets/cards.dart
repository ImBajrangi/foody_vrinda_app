import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: elevation != null ? elevation! * 2 : 8,
            offset: Offset(0, elevation ?? 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: card,
        ),
      );
    }

    return card;
  }
}

class ShopCard extends StatelessWidget {
  final String name;
  final String? address;
  final String? imageUrl;
  final bool isOpen;
  final String? schedule;
  final VoidCallback? onTap;

  const ShopCard({
    super.key,
    required this.name,
    this.address,
    this.imageUrl,
    this.isOpen = true,
    this.schedule,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppTheme.background,
                          child: const Icon(
                            Icons.restaurant,
                            size: 48,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      )
                    : Container(
                        color: AppTheme.background,
                        child: const Icon(
                          Icons.restaurant,
                          size: 48,
                          color: AppTheme.textTertiary,
                        ),
                      ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? AppTheme.statusReady
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOpen
                                ? AppTheme.statusReadyText
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      address!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (schedule != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          schedule!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuItemCard extends StatelessWidget {
  final String name;
  final double price;
  final String? imageUrl;
  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const MenuItemCard({
    super.key,
    required this.name,
    required this.price,
    this.imageUrl,
    this.quantity = 0,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.background,
                        child: const Icon(
                          Icons.fastfood,
                          size: 40,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    )
                  : Container(
                      color: AppTheme.background,
                      child: const Icon(
                        Icons.fastfood,
                        size: 40,
                        color: AppTheme.textTertiary,
                      ),
                    ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 8),

                // Add/Quantity controls
                if (quantity == 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Add'),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: onDecrement,
                          icon: const Icon(
                            Icons.remove,
                            color: AppTheme.primaryBlue,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        Text(
                          quantity.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          onPressed: onIncrement,
                          icon: const Icon(
                            Icons.add,
                            color: AppTheme.primaryBlue,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
