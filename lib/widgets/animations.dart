import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../config/lottie_assets.dart';
import '../config/theme.dart';

/// Animated loading indicator with Lottie
/// Animated loading indicator with Lottie
class AnimatedLoader extends StatefulWidget {
  final double size;
  final String? message;

  const AnimatedLoader({super.key, this.size = 150, this.message});

  @override
  State<AnimatedLoader> createState() => _AnimatedLoaderState();
}

class _AnimatedLoaderState extends State<AnimatedLoader> {
  bool _showAnimation = false;

  @override
  void initState() {
    super.initState();
    // Only show animation if loading takes longer than 500ms
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _showAnimation = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showAnimation ? 1.0 : 0.0,
      child: Column(
        key: ValueKey(widget.message),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_showAnimation)
            Lottie.network(
              LottieAssets.foodLoading,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: widget.size,
                height: widget.size,
                padding: const EdgeInsets.all(32),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          if (widget.message != null && _showAnimation) ...[
            const SizedBox(height: 16),
            Text(
              widget.message!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state with Lottie animation
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String animationType;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.animationType = 'cart',
    this.onAction,
    this.actionLabel,
  });

  String get _animationUrl {
    switch (animationType) {
      case 'cart':
        return LottieAssets.emptyCart;
      case 'search':
        return LottieAssets.emptySearch;
      case 'box':
        return LottieAssets.emptyBox;
      case 'data':
        return LottieAssets.noData;
      case 'profile':
        return LottieAssets.profile;
      default:
        return LottieAssets.emptyCart;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              _animationUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.inbox_outlined,
                size: 80,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Success animation overlay
class SuccessAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final String? message;

  const SuccessAnimation({super.key, this.onComplete, this.message});

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation> {
  @override
  void initState() {
    super.initState();
    if (widget.onComplete != null) {
      Future.delayed(const Duration(milliseconds: 2000), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.network(
              LottieAssets.orderSuccess,
              width: 200,
              height: 200,
              repeat: false,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.check_circle,
                size: 80,
                color: AppTheme.success,
              ),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Order status animation
class OrderStatusAnimation extends StatelessWidget {
  final String status;
  final double size;

  const OrderStatusAnimation({
    super.key,
    required this.status,
    this.size = 120,
  });

  String get _animationUrl {
    switch (status.toLowerCase()) {
      case 'new':
        return LottieAssets.newOrder;
      case 'preparing':
        return LottieAssets.preparing;
      case 'ready_for_pickup':
        return LottieAssets.ready;
      case 'out_for_delivery':
        return LottieAssets.outForDelivery;
      case 'completed':
        return LottieAssets.success;
      default:
        return LottieAssets.foodLoading;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.network(
      _animationUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.local_shipping,
        size: size * 0.6,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

/// Celebration confetti overlay
class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Lottie.network(
        LottieAssets.confetti,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        repeat: false,
      ),
    );
  }
}

/// Animated button with micro-interaction
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 24,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          widget.icon,
          color: widget.color ?? AppTheme.primaryBlue,
          size: widget.size,
        ),
      ),
    );
  }
}

/// Bouncy add to cart button
class BouncyAddButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isAdded;

  const BouncyAddButton({super.key, this.onPressed, this.isAdded = false});

  @override
  State<BouncyAddButton> createState() => _BouncyAddButtonState();
}

class _BouncyAddButtonState extends State<BouncyAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BouncyAddButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdded && !oldWidget.isAdded) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounceAnimation,
      child: ElevatedButton(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.isAdded
              ? AppTheme.success
              : AppTheme.primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.isAdded ? Icons.check : Icons.add, size: 18),
            const SizedBox(width: 4),
            Text(widget.isAdded ? 'Added!' : 'Add'),
          ],
        ),
      ),
    );
  }
}

/// Pulse animation wrapper
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final bool animate;

  const PulseAnimation({super.key, required this.child, this.animate = true});

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

/// Shake animation for errors
class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final bool shake;

  const ShakeAnimation({super.key, required this.child, this.shake = false});

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: widget.child,
        );
      },
    );
  }
}
