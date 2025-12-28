import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

/// Manages real-time order listeners and triggers notifications for staff
class OrderNotificationManager {
  static final OrderNotificationManager _instance =
      OrderNotificationManager._internal();
  factory OrderNotificationManager() => _instance;
  OrderNotificationManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  Set<String> _knownOrderIds = {};
  bool _isFirstLoad = true;
  UserRole? _currentUserRole;

  /// Start listening for new orders based on user role
  Future<void> startListening({
    required UserRole userRole,
    String? shopId,
  }) async {
    // Stop any existing listener
    await stopListening();

    _currentUserRole = userRole;
    _isFirstLoad = true;
    _knownOrderIds.clear();

    // Initialize notification service
    await _notificationService.initialize();
    await _notificationService.requestPermissions();

    print(
      'OrderNotificationManager: Starting listener for role ${userRole.value}, shopId: $shopId',
    );

    // Build query - listen to recent orders only
    // Filter by shopId client-side to avoid composite index requirement
    Query<Map<String, dynamic>> query = _firestore.collection('orders');

    // Listen only to recent orders (last 24 hours) to avoid overwhelming on startup
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    query = query.where(
      'createdAt',
      isGreaterThan: Timestamp.fromDate(yesterday),
    );

    _ordersSubscription = query.snapshots().listen(
      (snapshot) => _handleOrdersSnapshot(snapshot, shopId, userRole),
      onError: (error) {
        print('OrderNotificationManager: Error listening to orders: $error');
      },
    );
  }

  void _handleOrdersSnapshot(
    QuerySnapshot snapshot,
    String? shopId,
    UserRole userRole,
  ) {
    // Filter by shopId client-side for owner/kitchen roles
    var docs = snapshot.docs;
    if ((userRole == UserRole.owner || userRole == UserRole.kitchen) &&
        shopId != null) {
      docs = docs
          .where((doc) => (doc.data() as Map?)?.containsKey('shopId') == true)
          .where((doc) => (doc.data() as Map)['shopId'] == shopId)
          .toList();
    }

    final currentOrderIds = docs.map((doc) => doc.id).toSet();

    if (_isFirstLoad) {
      // On first load, just record existing order IDs without notifying
      _knownOrderIds = currentOrderIds;
      _isFirstLoad = false;
      print(
        'OrderNotificationManager: Initial load - ${_knownOrderIds.length} existing orders',
      );
      return;
    }

    // Find new orders
    final newOrderIds = currentOrderIds.difference(_knownOrderIds);

    if (newOrderIds.isEmpty) {
      // Update known orders (some may have been removed)
      _knownOrderIds = currentOrderIds;
      return;
    }

    print(
      'OrderNotificationManager: ${newOrderIds.length} new order(s) detected',
    );

    // Show notification for each new order
    for (final orderId in newOrderIds) {
      final doc = snapshot.docs.firstWhere((d) => d.id == orderId);
      final order = OrderModel.fromFirestore(doc);
      _showNewOrderNotification(order);
    }

    // Update known orders
    _knownOrderIds = currentOrderIds;
  }

  void _showNewOrderNotification(OrderModel order) {
    print(
      'OrderNotificationManager: Showing notification for order ${order.orderNumber}',
    );

    _notificationService.showNewOrderNotification(
      orderId: order.id,
      customerName: order.customerName,
      amount: order.totalAmount,
      userRole: _currentUserRole,
    );
  }

  /// Stop listening for orders
  Future<void> stopListening() async {
    await _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _knownOrderIds.clear();
    _isFirstLoad = true;
    print('OrderNotificationManager: Stopped listening');
  }

  /// Check if currently listening
  bool get isListening => _ordersSubscription != null;

  /// Get current user role
  UserRole? get currentUserRole => _currentUserRole;
}
