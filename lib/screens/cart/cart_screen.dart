import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../models/shop_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';
import '../../services/order_service.dart';
import '../../services/shop_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/inputs.dart';
import '../../widgets/address_autocomplete_field.dart';
import '../../widgets/location_picker_dialog.dart';
import 'package:latlong2/latlong.dart' as ll2;
import '../order/order_tracking_screen.dart';
import '../auth/login_screen.dart';
import '../../models/order_model.dart';

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

  // Payment settings
  bool _onlinePaymentsEnabled = true;
  bool _codEnabled = true;

  // Store order details for use after payment success
  String? _pendingCustomerName;
  String? _pendingCustomerPhone;
  String? _pendingDeliveryAddress;
  ll2.LatLng? _deliveryLocation; // Store coordinates for distance calculation
  PaymentMethod? _selectedPaymentMethod;
  StreamSubscription? _paymentSettingsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _initPaymentSettingsListener();
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
    _paymentSettingsSubscription?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initPaymentSettingsListener() {
    _paymentSettingsSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('paymentConfig')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data()!;
              setState(() {
                _onlinePaymentsEnabled = data['onlinePaymentsEnabled'] ?? true;
                _codEnabled = data['codEnabled'] ?? true;
              });
            }
          },
          onError: (e) {
            debugPrint('CartScreen: Error listening to payment settings: $e');
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Pre-fill user info if authenticated
    if (authProvider.isAuthenticated && _nameController.text.isEmpty) {
      _nameController.text = authProvider.userData?.displayName ?? '';
    }
    if (authProvider.isAuthenticated && _phoneController.text.isEmpty) {
      _phoneController.text = authProvider.userData?.phoneNumber ?? '';
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

                        // ========== PRICING BREAKDOWN ==========
                        Builder(
                          builder: (context) {
                            final subtotal = cartProvider.totalAmount;
                            final deliveryCharge = _shop?.deliveryCharge ?? 0.0;
                            final gstPercentage = _shop?.gstPercentage ?? 5.0;
                            final gstAmount = subtotal * (gstPercentage / 100);
                            final total = subtotal + deliveryCharge + gstAmount;
                            final minimumOrder =
                                _shop?.minimumOrderAmount ?? 0.0;
                            final isBelowMinimum =
                                subtotal < minimumOrder && minimumOrder > 0;

                            return Column(
                              children: [
                                // Minimum order warning - Red alert
                                if (isBelowMinimum) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.error.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppTheme.error,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Minimum order: ₹${minimumOrder.toInt()}. Add ₹${(minimumOrder - subtotal).toInt()} more.',
                                            style: const TextStyle(
                                              color: AppTheme.error,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Subtotal
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Subtotal',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '₹${subtotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Delivery Charge
                                if (deliveryCharge > 0) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Delivery Charge',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '₹${deliveryCharge.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // GST
                                if (gstPercentage > 0) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'GST (${gstPercentage.toStringAsFixed(0)}%)',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '₹${gstAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Total
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '₹${total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.paymentBlue,
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

                          AddressAutocompleteField(
                            controller: _addressController,
                            labelText: 'Delivery Address',
                            hintText: 'Start typing your address...',
                            onAddressSelected: (address, location) {
                              setState(() {
                                _deliveryLocation = location;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          // Pick on Map button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                final ll2.LatLng? picked =
                                    await showDialog<ll2.LatLng>(
                                      context: context,
                                      builder: (context) =>
                                          LocationPickerDialog(
                                            initialLocation: _deliveryLocation,
                                          ),
                                    );
                                if (picked != null) {
                                  setState(() {
                                    _deliveryLocation = picked;
                                    // If address is empty, we set a placeholder or hint
                                    if (_addressController.text.isEmpty) {
                                      _addressController.text =
                                          'Pinned Location (${picked.latitude.toStringAsFixed(4)}, ${picked.longitude.toStringAsFixed(4)})';
                                    }
                                  });
                                }
                              },
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Pick on Map'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          // Validation message for address
                          if (_addressController.text.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '',
                                style: TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Payment Method Selection - Blue Trust Theme
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.paymentBlue.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Blue gradient header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.paymentGradient,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.verified_user_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Payment Method',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '100% Secure Payments',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.shield_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        // Payment options
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildPaymentOption(
                                title: 'Cash on Delivery',
                                subtitle: _codEnabled
                                    ? 'Pay when you receive your food'
                                    : 'Temporarily unavailable',
                                icon: Icons.payments_outlined,
                                method: PaymentMethod.cash,
                                isEnabled: _codEnabled,
                              ),
                              const SizedBox(height: 12),
                              _buildPaymentOption(
                                title: 'Online Payment',
                                subtitle: _onlinePaymentsEnabled
                                    ? 'Pay securely via Razorpay'
                                    : 'Temporarily unavailable',
                                icon: Icons.account_balance_wallet_outlined,
                                method: PaymentMethod.online,
                                isEnabled: _onlinePaymentsEnabled,
                              ),
                            ],
                          ),
                        ),
                      ],
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
                child: Builder(
                  builder: (context) {
                    final subtotal = cartProvider.totalAmount;
                    final deliveryCharge = _shop?.deliveryCharge ?? 0.0;
                    final gstPercentage = _shop?.gstPercentage ?? 5.0;
                    final gstAmount = subtotal * (gstPercentage / 100);
                    final total = subtotal + deliveryCharge + gstAmount;
                    final formattedTotal = '₹${total.toStringAsFixed(0)}';
                    final minimumOrder = _shop?.minimumOrderAmount ?? 0.0;
                    final isBelowMinimum =
                        subtotal < minimumOrder && minimumOrder > 0;

                    return AppButton(
                      text: isBelowMinimum
                          ? 'Add ₹${(minimumOrder - subtotal).toInt()} more'
                          : 'Review Order • $formattedTotal',
                      isFullWidth: true,
                      isLoading: _isLoading,
                      height: 52,
                      onPressed: (_shop?.isOpen ?? false) && !isBelowMinimum
                          ? _showOrderConfirmation
                          : null,
                    );
                  },
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

  /// Show order confirmation sheet before placing order
  void _showOrderConfirmation() {
    // First validate the form - address is required
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all delivery details'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    // Check if address is provided
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your delivery address'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final subtotal = cartProvider.totalAmount;
    final deliveryCharge = _shop?.deliveryCharge ?? 0.0;
    final gstPercentage = _shop?.gstPercentage ?? 0.0;
    final gstAmount = gstPercentage > 0
        ? subtotal * (gstPercentage / 100)
        : 0.0;
    final total = subtotal + deliveryCharge + gstAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Delivery Address
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppTheme.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivery To',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              _addressController.text.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Cart Items
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.25,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cartProvider.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = cartProvider.items[index];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.menuItem.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '₹${(item.menuItem.price * item.quantity).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
                // Pricing Breakdown
                _buildPriceRow('Subtotal', subtotal),
                if (gstPercentage > 0)
                  _buildPriceRow(
                    'GST (${gstPercentage.toStringAsFixed(0)}%)',
                    gstAmount,
                  ),
                if (deliveryCharge > 0)
                  _buildPriceRow('Delivery Charge', deliveryCharge),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Payment Method Selection
                const Text(
                  'Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentChipWithCallback(
                        'Cash on Delivery',
                        Icons.payments_outlined,
                        PaymentMethod.cash,
                        _codEnabled,
                        () {
                          setSheetState(
                            () => _selectedPaymentMethod = PaymentMethod.cash,
                          );
                          setState(() {}); // Also update parent
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPaymentChipWithCallback(
                        'Online Pay',
                        Icons.account_balance_wallet_outlined,
                        PaymentMethod.online,
                        _onlinePaymentsEnabled,
                        () {
                          setSheetState(
                            () => _selectedPaymentMethod = PaymentMethod.online,
                          );
                          setState(() {}); // Also update parent
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Confirm Button
                AppButton(
                  text: _selectedPaymentMethod == PaymentMethod.online
                      ? 'Pay & Place Order'
                      : 'Confirm Order',
                  isFullWidth: true,
                  height: 50,
                  onPressed: _selectedPaymentMethod == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          _placeOrder();
                        },
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(
    String label,
    IconData icon,
    PaymentMethod method,
    bool isEnabled,
  ) {
    final isSelected = _selectedPaymentMethod == method;
    final isCash = method == PaymentMethod.cash;

    // Vibrant colors for each payment type
    final activeColor = isCash
        ? const Color(0xFF00C853)
        : const Color(0xFF2962FF);
    final bgColor = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : (isEnabled ? Colors.white : Colors.grey.shade100);

    return GestureDetector(
      onTap: isEnabled
          ? () => setState(() => _selectedPaymentMethod = method)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.borderLight,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with colored background
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isEnabled
                          ? activeColor.withValues(alpha: 0.1)
                          : Colors.grey.shade200),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : (isEnabled ? activeColor : Colors.grey),
              ),
            ),
            const SizedBox(height: 10),
            // Label
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isEnabled
                    ? (isSelected ? activeColor : AppTheme.textPrimary)
                    : Colors.grey,
                letterSpacing: isSelected ? 0.3 : 0,
              ),
            ),
            const SizedBox(height: 4),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Payment chip with custom callback for use in StatefulBuilder
  Widget _buildPaymentChipWithCallback(
    String label,
    IconData icon,
    PaymentMethod method,
    bool isEnabled,
    VoidCallback onTap,
  ) {
    final isSelected = _selectedPaymentMethod == method;
    final isCash = method == PaymentMethod.cash;

    // Vibrant colors for each payment type
    final activeColor = isCash
        ? const Color(0xFF00C853)
        : const Color(0xFF2962FF);
    final bgColor = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : (isEnabled ? Colors.white : Colors.grey.shade100);

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.borderLight,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with colored background
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isEnabled
                          ? activeColor.withValues(alpha: 0.1)
                          : Colors.grey.shade200),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : (isEnabled ? activeColor : Colors.grey),
              ),
            ),
            const SizedBox(height: 10),
            // Label
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isEnabled
                    ? (isSelected ? activeColor : AppTheme.textPrimary)
                    : Colors.grey,
                letterSpacing: isSelected ? 0.3 : 0,
              ),
            ),
            const SizedBox(height: 4),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
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

    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    // Double check enabled status
    if (_selectedPaymentMethod == PaymentMethod.online &&
        !_onlinePaymentsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Online payments are temporarily disabled'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedPaymentMethod == PaymentMethod.cash && !_codEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cash on Delivery is temporarily disabled'),
          backgroundColor: Colors.red,
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

    // ========== MINIMUM ORDER VALIDATION ==========
    final subtotal = cartProvider.totalAmount;
    final minimumOrder = _shop?.minimumOrderAmount ?? 0.0;
    if (subtotal < minimumOrder && minimumOrder > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum order amount is ₹${minimumOrder.toInt()}. Add ₹${(minimumOrder - subtotal).toInt()} more.',
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    // Store details for use after payment success
    _pendingCustomerName = _nameController.text.trim();
    _pendingCustomerPhone = _phoneController.text.trim();
    _pendingDeliveryAddress = _addressController.text.trim();

    if (_selectedPaymentMethod == PaymentMethod.cash) {
      await _createOrder();
      return;
    }

    // Check if on web - Razorpay doesn't work on web
    if (kIsWeb) {
      _showWebNotSupportedDialog();
      return;
    }

    // ========== CALCULATE COMPLETE TOTAL ==========
    final deliveryCharge = _shop?.deliveryCharge ?? 0.0;
    final gstPercentage = _shop?.gstPercentage ?? 5.0;
    final gstAmount = subtotal * (gstPercentage / 100);
    final totalAmount = subtotal + deliveryCharge + gstAmount;

    // Calculate total in paise (Razorpay expects amount in smallest currency unit)
    final totalAmountInPaise = (totalAmount * 100).toInt();

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

  Future<void> _createOrder({String? paymentId}) async {
    setState(() => _isLoading = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ========== CALCULATE PRICING BREAKDOWN ==========
    final subtotal = cartProvider.totalAmount;
    final deliveryCharge = _shop?.deliveryCharge ?? 0.0;
    final gstPercentage = _shop?.gstPercentage ?? 5.0;
    final gstAmount = subtotal * (gstPercentage / 100);
    final totalAmount = subtotal + deliveryCharge + gstAmount;

    try {
      final orderId = await _orderService.createOrder(
        shopId: _shop!.id,
        userId: authProvider.user?.uid,
        customerName: _pendingCustomerName!,
        customerPhone: _pendingCustomerPhone!,
        deliveryAddress: _pendingDeliveryAddress!,
        cartItems: cartProvider.items,
        paymentId: paymentId,
        paymentMethod: _selectedPaymentMethod!,
        customerLatitude: _deliveryLocation?.latitude,
        customerLongitude: _deliveryLocation?.longitude,
        subtotal: subtotal,
        deliveryCharge: deliveryCharge,
        gstAmount: gstAmount,
        totalAmount: totalAmount,
      );

      debugPrint('CartScreen: Order created successfully - $orderId');

      // Update user's phone number in Firestore if not already set
      if (authProvider.isAuthenticated &&
          (authProvider.userData?.phoneNumber == null ||
              authProvider.userData!.phoneNumber!.isEmpty)) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(authProvider.user!.uid)
            .update({'phoneNumber': _pendingCustomerPhone});
      }

      cartProvider.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _selectedPaymentMethod == PaymentMethod.online
                      ? 'Payment successful! Order placed.'
                      : 'Order placed successfully!',
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
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
      debugPrint('CartScreen: Error creating order - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order creation failed. Please contact support. Error: $e',
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
    _createOrder(paymentId: response.paymentId);
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

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required PaymentMethod method,
    required bool isEnabled,
  }) {
    final isSelected = _selectedPaymentMethod == method;
    final isOnlinePayment = method == PaymentMethod.online;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled
              ? () => setState(() => _selectedPaymentMethod = method)
              : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isEnabled ? 1.0 : 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isOnlinePayment
                          ? AppTheme.paymentBlueBg
                          : AppTheme.success.withOpacity(0.08))
                    : AppTheme.background,
                border: Border.all(
                  color: isSelected
                      ? (isOnlinePayment
                            ? AppTheme.paymentBlue
                            : AppTheme.success)
                      : AppTheme.border,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // Icon container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? (isOnlinePayment
                                ? AppTheme.paymentGradient
                                : AppTheme.successGradient)
                          : null,
                      color: isSelected ? null : AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 15,
                            color: isSelected
                                ? (isOnlinePayment
                                      ? AppTheme.paymentBlueDark
                                      : AppTheme.success)
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selection indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? (isOnlinePayment
                                ? AppTheme.paymentBlue
                                : AppTheme.success)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? (isOnlinePayment
                                  ? AppTheme.paymentBlue
                                  : AppTheme.success)
                            : AppTheme.border,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
