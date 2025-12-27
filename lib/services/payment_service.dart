import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Payment Service for handling Razorpay payments
/// On mobile: Uses razorpay_flutter package (handled externally)
/// On web: Returns special error code to trigger direct order creation
class PaymentService {
  static const String razorpayTestKey = "rzp_test_RU9lPJQl5wqQFM";

  // Singleton instance
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  bool _initialized = false;

  // Callbacks
  Function(String paymentId)? _onSuccess;
  Function(int code, String? message)? _onError;

  /// Check if payment is supported on current platform
  bool get isSupported => !kIsWeb;

  /// Check if we're on web platform
  bool get isWeb => kIsWeb;

  /// Initialize payment service
  void initialize({
    required Function(String paymentId) onSuccess,
    required Function(int code, String? message) onError,
    Function(String walletName)? onExternalWallet,
  }) {
    _onSuccess = onSuccess;
    _onError = onError;
    _initialized = true;
    debugPrint('PaymentService: Initialized (isWeb: $kIsWeb)');
  }

  /// Open payment checkout
  /// On web, this will trigger the error callback with WEB_NOT_SUPPORTED
  void openCheckout({
    required double amount,
    required String customerName,
    String? customerEmail,
    required String customerPhone,
    String description = "Order Payment",
    String? orderId,
  }) {
    debugPrint(
      'PaymentService: openCheckout called - amount: ₹$amount, isWeb: $kIsWeb',
    );

    if (kIsWeb) {
      // On web, Razorpay Flutter is not supported
      // Call error callback with special code to trigger direct order creation
      debugPrint('PaymentService: Web platform - triggering WEB_NOT_SUPPORTED');
      _onError?.call(-2, 'WEB_NOT_SUPPORTED');
      return;
    }

    if (!_initialized) {
      debugPrint('PaymentService: Not initialized! Call initialize() first.');
      _onError?.call(-1, 'Payment service not initialized');
      return;
    }

    // On mobile, this would open the Razorpay checkout
    // For now, we'll simulate success for testing
    // TODO: Implement actual razorpay_flutter integration for mobile
    debugPrint('PaymentService: Mobile platform - simulating payment success');
    Future.delayed(const Duration(milliseconds: 500), () {
      _onSuccess?.call(
        'MOBILE_TEST_PAYMENT_${DateTime.now().millisecondsSinceEpoch}',
      );
    });
  }

  /// Dispose payment service
  void dispose() {
    _initialized = false;
  }
}
