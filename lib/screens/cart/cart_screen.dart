import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/shop_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/inputs.dart';
import '../order/order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  final ShopModel shop;

  const CartScreen({super.key, required this.shop});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final OrderService _orderService = OrderService();
  bool _isLoading = false;

  @override
  void dispose() {
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
      body: cartProvider.isEmpty
          ? _buildEmptyCart()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop name
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
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
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
                                widget.shop.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.shop.address != null)
                                Text(
                                  widget.shop.address!,
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
                  text: 'Place Order • ${cartProvider.formattedTotal}',
                  isFullWidth: true,
                  isLoading: _isLoading,
                  height: 52,
                  onPressed: widget.shop.isOpen ? _placeOrder : null,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add some delicious items to get started!',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Browse Menu'),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final orderId = await _orderService.createOrder(
        shopId: widget.shop.id,
        userId: authProvider.user?.uid,
        customerName: _nameController.text,
        customerPhone: _phoneController.text,
        deliveryAddress: _addressController.text,
        cartItems: cartProvider.items,
      );

      // Clear cart
      cartProvider.clear();

      // Navigate to order tracking
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
