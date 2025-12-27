import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../config/theme.dart';
import '../../models/shop_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';
import '../../services/order_service.dart';
import '../../services/shop_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/inputs.dart';
import '../order/order_tracking_screen.dart';
import '../auth/login_screen.dart';

class CartScreen extends StatefulWidget {
  final ShopModel? shop;

  const CartScreen({super.key, this.shop});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final OrderService _orderService = OrderService();
  final ShopService _shopService = ShopService();
  Razorpay? _razorpay; // Nullable - only initialized on mobile

  bool _isLoading = false;
  ShopModel? _shop;
  bool _shopLoading = true;

  // Store order details for use after payment success
  String? _pendingCustomerName;
  String? _pendingCustomerPhone;
  String? _pendingDeliveryAddress;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    if (widget.shop != null) {
      _shop = widget.shop;
      _shopLoading = false;
    } else {
      _loadShop();
    }
  }

  Future<void> _loadShop() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.shopId != null) {
      final shop = await _shopService.getShop(cartProvider.shopId!);
      if (mounted) {
        setState(() {
          _shop = shop;
          _shopLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _shopLoading = false);
    }
  }

  void _initializeRazorpay() {
    // Razorpay only works on Android and iOS, not on Web
    if (kIsWeb) {
      debugPrint('CartScreen: Razorpay not available on web platform');
      return;
    }
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Pre-fill user info if authenticated
    if (authProvider.isAuthenticated && _nameController.text.isEmpty) {
      _nameController.text = authProvider.userData?.displayName ?? '';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: AppTheme.cardBackground,
      ),
      body: _shopLoading
          ? const Center(child: AnimatedLoader(size: 80))
          : cartProvider.isEmpty
          ? _buildEmptyCart()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop name
                  if (_shop != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.store,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _shop!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_shop!.address != null)
                                  Text(
                                    _shop!.address!,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Cart items
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Cart Items',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        ...cartProvider.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.menuItem.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        item.menuItem.formattedPrice,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () => cartProvider
                                            .decrementItem(item.menuItem.id),
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 18,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          item.quantity.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => cartProvider
                                            .incrementItem(item.menuItem.id),
                                        icon: const Icon(Icons.add, size: 18),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    item.formattedTotal,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              cartProvider.formattedTotal,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Order form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),

                          AppInputField(
                            controller: _nameController,
                            label: 'Full Name',
                            hintText: 'Enter your name',
                            prefixIcon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          AppInputField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hintText: 'Enter your phone number',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (value.length < 10) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          AppInputField(
                            controller: _addressController,
                            label: 'Delivery Address',
                            hintText: 'Enter your delivery address',
                            prefixIcon: Icons.location_on_outlined,
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your delivery address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
      bottomNavigationBar: cartProvider.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: AppButton(
                  text: 'Pay & Place Order • ${cartProvider.formattedTotal}',
                  isFullWidth: true,
                  isLoading: _isLoading,
                  height: 52,
                  onPressed: (_shop?.isOpen ?? false) ? _placeOrder : null,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyCart() {
    return EmptyState(
      title: 'Your cart is empty',
      subtitle: 'Add some delicious items to get started!',
      animationType: 'cart',
      actionLabel: 'Browse Menu',
      onAction: () => Navigator.pop(context),
    );
  }

  /// Initiate payment via Razorpay
  /// Order is created ONLY after successful payment
  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (cartProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    // Check if user is logged in (anonymous users cannot pay)
    if (!authProvider.isAuthenticated ||
        (authProvider.user?.isAnonymous ?? true)) {
      _showLoginRequiredDialog();
      return;
    }

    // Store details for use after payment success
    _pendingCustomerName = _nameController.text.trim();
    _pendingCustomerPhone = _phoneController.text.trim();
    _pendingDeliveryAddress = _addressController.text.trim();

    // Check if on web - Razorpay doesn't work on web
    if (kIsWeb) {
      _showWebNotSupportedDialog();
      return;
    }

    // Calculate total in paise (Razorpay expects amount in smallest currency unit)
    final totalAmountInPaise = (cartProvider.totalAmount * 100).toInt();

    final options = {
      'key': 'rzp_test_RU9lPJQl5wqQFM', // Razorpay Test Key
      'amount': totalAmountInPaise,
      'currency': 'INR',
      'name': 'CloudKitchen',
      'description': 'Order Payment',
      'prefill': {
        'name': _pendingCustomerName,
        'contact': _pendingCustomerPhone,
        'email': authProvider.user?.email ?? '',
      },
      'notes': {'shopId': _shop?.id ?? '', 'address': _pendingDeliveryAddress},
      'theme': {'color': '#0071e3'},
    };

    try {
      debugPrint('CartScreen: Opening Razorpay checkout...');
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('CartScreen: Error opening Razorpay - $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open payment: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  /// Show dialog explaining web payment is not supported
  void _showWebNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Use Mobile App'),
          ],
        ),
        content: const Text(
          'Payment is only available on the mobile app (Android/iOS). Please download our app to place orders with payment.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Show dialog prompting user to login
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Login Required'),
          ],
        ),
        content: const Text(
          'You need to be logged in to place an order and make a payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  /// Called on successful Razorpay payment
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('CartScreen: Payment successful - ${response.paymentId}');
    setState(() => _isLoading = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final orderId = await _orderService.createOrder(
        shopId: _shop!.id,
        userId: authProvider.user?.uid,
        customerName: _pendingCustomerName!,
        customerPhone: _pendingCustomerPhone!,
        deliveryAddress: _pendingDeliveryAddress!,
        cartItems: cartProvider.items,
        paymentId: response.paymentId,
      );

      debugPrint('CartScreen: Order created successfully - $orderId');
      cartProvider.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Payment successful! Order placed.'),
              ],
            ),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      debugPrint('CartScreen: Error creating order after payment - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment received but order creation failed. Please contact support. Error: $e',
            ),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Called on Razorpay payment error
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
      'CartScreen: Payment failed - ${response.code}: ${response.message}',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(response.message ?? 'Payment cancelled or failed.'),
              ),
            ],
          ),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Called when user selects an external wallet (e.g., Paytm, PhonePe)
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('CartScreen: External wallet selected - ${response.walletName}');
    // This is informational; actual payment flow will continue through Razorpay
  }
}
