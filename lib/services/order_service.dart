import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new order
  Future<String> createOrder({
    required String shopId,
    String? userId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<CartItemModel> cartItems,
    String? paymentId,
    bool isTestOrder = false,
  }) async {
    try {
      print('OrderService: Creating order for shop $shopId');
      print('OrderService: Customer: $customerName, Phone: $customerPhone');
      print('OrderService: Items count: ${cartItems.length}');

      final items = cartItems
          .map(
            (cartItem) => OrderItem(
              menuItemId: cartItem.menuItem.id,
              name: cartItem.menuItem.name,
              price: cartItem.menuItem.price,
              quantity: cartItem.quantity,
            ),
          )
          .toList();

      final totalAmount = cartItems.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );

      print('OrderService: Total amount: $totalAmount');

      // Generate order number based on timestamp
      final now = DateTime.now();
      final orderNumber = '${now.millisecondsSinceEpoch}';

      final orderData = {
        'shopId': shopId,
        'userId': userId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'items': items.map((item) => item.toMap()).toList(),
        'totalAmount': totalAmount,
        'status': 'new',
        'paymentId': paymentId,
        'isTestOrder': isTestOrder,
        'orderNumber': orderNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('OrderService: Saving order to Firestore...');
      final docRef = await _firestore.collection('orders').add(orderData);

      print('OrderService: Order created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('OrderService: Error creating order: $e');
      rethrow;
    }
  }

  // Get order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return OrderModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('OrderService: Error getting order: $e');
      return null;
    }
  }

  // Order stream
  Stream<OrderModel?> orderStream(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots().map((doc) {
      if (doc.exists) {
        print('OrderService: Order stream update for $orderId');
        return OrderModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Get orders for a shop (without ordering to avoid index requirement)
  Stream<List<OrderModel>> getShopOrders(String shopId, {OrderStatus? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                a.createdAt ?? DateTime.now(),
              ),
            ),
    );
  }

  // Get active orders for a shop (new, preparing, ready_for_pickup, out_for_delivery)
  Stream<List<OrderModel>> getActiveOrders(String shopId) {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where(
          'status',
          whereIn: ['new', 'preparing', 'ready_for_pickup', 'out_for_delivery'],
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                ),
        );
  }

  // Get kitchen orders (new and preparing)
  Stream<List<OrderModel>> getKitchenOrders(String? shopId) {
    Query<Map<String, dynamic>> query = _firestore.collection('orders');

    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    return query
        .where('status', whereIn: ['new', 'preparing'])
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                ),
        );
  }

  // Get delivery orders (ready_for_pickup and out_for_delivery)
  Stream<List<OrderModel>> getDeliveryOrders(String? shopId) {
    Query<Map<String, dynamic>> query = _firestore.collection('orders');

    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    return query
        .where('status', whereIn: ['ready_for_pickup', 'out_for_delivery'])
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                ),
        );
  }

  // Get delivery orders for multiple shops
  Stream<List<OrderModel>> getDeliveryOrdersMultiShop(List<String> shopIds) {
    if (shopIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('orders')
        .where('shopId', whereIn: shopIds)
        .where('status', whereIn: ['ready_for_pickup', 'out_for_delivery'])
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                ),
        );
  }

  // Get completed orders for a shop
  Stream<List<OrderModel>> getCompletedOrders(
    String shopId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                ),
        );
  }

  // Get user's orders
  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                ),
        );
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      print('OrderService: Updating order $orderId to status ${status.value}');
      await _firestore.collection('orders').doc(orderId).update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('OrderService: Order status updated successfully');
    } catch (e) {
      print('OrderService: Error updating order status: $e');
      rethrow;
    }
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
      print('OrderService: Order $orderId cancelled');
    } catch (e) {
      print('OrderService: Error cancelling order: $e');
      rethrow;
    }
  }

  // Get all orders (developer only)
  Stream<List<OrderModel>> getAllOrders({int limit = 50}) {
    return _firestore
        .collection('orders')
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort(
                  (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
                    a.createdAt ?? DateTime.now(),
                  ),
                ),
        );
  }

  // Get orders today
  Future<List<OrderModel>> getOrdersToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _firestore
        .collection('orders')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();

    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  }

  // Get order statistics for a shop
  Future<Map<String, dynamic>> getOrderStats(String shopId) async {
    // Get all orders for this shop (not just completed)
    final allOrdersSnapshot = await _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .get();

    final allOrders = allOrdersSnapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc))
        .toList();

    // Calculate status counts
    int pending = 0;
    int preparing = 0;
    int ready = 0;
    int completed = 0;

    for (final order in allOrders) {
      switch (order.status) {
        case OrderStatus.newOrder:
          pending++;
          break;
        case OrderStatus.preparing:
          preparing++;
          break;
        case OrderStatus.readyForPickup:
          ready++;
          break;
        case OrderStatus.outForDelivery:
          completed++;
          break;
        case OrderStatus.completed:
          completed++;
          break;
      }
    }

    // Calculate weekly sales (last 7 days)
    final now = DateTime.now();
    final weeklySales = List<double>.filled(7, 0.0);

    for (final order in allOrders) {
      if (order.status == OrderStatus.completed) {
        final orderDate = order.createdAt;
        if (orderDate != null) {
          final dayOfWeek = orderDate.weekday - 1; // 0 = Monday, 6 = Sunday
          if (dayOfWeek >= 0 && dayOfWeek < 7) {
            // Check if this order is from the current week
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final startOfWeekDate = DateTime(
              startOfWeek.year,
              startOfWeek.month,
              startOfWeek.day,
            );
            if (orderDate.isAfter(startOfWeekDate) ||
                orderDate.isAtSameMomentAs(startOfWeekDate)) {
              weeklySales[dayOfWeek] += order.totalAmount;
            }
          }
        }
      }
    }

    // Calculate totals (from completed orders only)
    final completedOrders = allOrders
        .where((o) => o.status == OrderStatus.completed)
        .toList();

    final totalRevenue = completedOrders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );
    final totalOrders = completedOrders.length;
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'avgOrderValue': avgOrderValue,
      'pending': pending,
      'preparing': preparing,
      'ready': ready,
      'delivered': completed,
      'weeklySales': weeklySales,
    };
  }

  // Get delivery statistics for delivery staff dashboard
  Future<Map<String, dynamic>> getDeliveryStats(String? shopId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    // Build query based on shopId
    Query<Map<String, dynamic>> query = _firestore.collection('orders');
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    final snapshot = await query.get();
    final allOrders = snapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc))
        .toList();

    // Today's completed deliveries
    int todayDeliveries = 0;
    double todayCollections = 0.0;

    // Active orders (ready_for_pickup + out_for_delivery)
    int activeOrders = 0;

    // Weekly delivery counts (Mon-Sun)
    final weeklyDeliveries = List<int>.filled(7, 0);

    for (final order in allOrders) {
      final orderDate = order.createdAt;

      // Count active orders
      if (order.status == OrderStatus.readyForPickup ||
          order.status == OrderStatus.outForDelivery) {
        activeOrders++;
      }

      // Count completed orders
      if (order.status == OrderStatus.completed && orderDate != null) {
        // Today's stats
        if (orderDate.isAfter(startOfToday) ||
            orderDate.isAtSameMomentAs(startOfToday)) {
          todayDeliveries++;
          todayCollections += order.totalAmount;
        }

        // Weekly stats
        if (orderDate.isAfter(startOfWeekDate) ||
            orderDate.isAtSameMomentAs(startOfWeekDate)) {
          final dayOfWeek = orderDate.weekday - 1; // 0 = Monday
          if (dayOfWeek >= 0 && dayOfWeek < 7) {
            weeklyDeliveries[dayOfWeek]++;
          }
        }
      }
    }

    // Total completed deliveries (all time)
    final totalDeliveries = allOrders
        .where((o) => o.status == OrderStatus.completed)
        .length;

    // Total collections (all time)
    final totalCollections = allOrders
        .where((o) => o.status == OrderStatus.completed)
        .fold<double>(0, (sum, o) => sum + o.totalAmount);

    return {
      'todayDeliveries': todayDeliveries,
      'todayCollections': todayCollections,
      'activeOrders': activeOrders,
      'weeklyDeliveries': weeklyDeliveries,
      'totalDeliveries': totalDeliveries,
      'totalCollections': totalCollections,
    };
  }
}
