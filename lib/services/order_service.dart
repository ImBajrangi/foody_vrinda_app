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

    final order = OrderModel(
      id: '',
      shopId: shopId,
      userId: userId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      items: items,
      totalAmount: totalAmount,
      status: OrderStatus.newOrder,
      paymentId: paymentId,
      isTestOrder: isTestOrder,
    );

    final docRef = await _firestore
        .collection('orders')
        .add(order.toFirestore());
    return docRef.id;
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
      print('Error getting order: $e');
      return null;
    }
  }

  // Order stream
  Stream<OrderModel?> orderStream(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
  }

  // Get orders for a shop
  Stream<List<OrderModel>> getShopOrders(String shopId, {OrderStatus? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get kitchen orders (new and preparing)
  Stream<List<OrderModel>> getKitchenOrders(String shopId) {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['new', 'preparing'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get delivery orders (ready_for_pickup and out_for_delivery)
  Stream<List<OrderModel>> getDeliveryOrders(String shopId) {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['ready_for_pickup', 'out_for_delivery'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get completed orders for a shop
  Stream<List<OrderModel>> getCompletedOrders(
    String shopId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'completed');

    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get user's orders
  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).delete();
  }

  // Get all orders (developer only)
  Stream<List<OrderModel>> getAllOrders({int limit = 50}) {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
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
    final snapshot = await _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'completed')
        .get();

    final orders = snapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc))
        .toList();

    final totalRevenue = orders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );
    final totalOrders = orders.length;
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'avgOrderValue': avgOrderValue,
    };
  }
}
