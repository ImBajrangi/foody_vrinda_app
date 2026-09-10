import 'dart:async';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';
import '../models/cash_transaction_model.dart';
import 'supabase_service.dart';
import '../config/supabase_config.dart';

class OrderService {
  final SupabaseService _supabase = SupabaseService();

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
    PaymentMethod paymentMethod = PaymentMethod.cash,
    double? customerLatitude,
    double? customerLongitude,
    double subtotal = 0.0,
    double deliveryCharge = 0.0,
    double gstAmount = 0.0,
    double? totalAmount,
  }) async {
    try {
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

      final calculatedSubtotal = subtotal > 0
          ? subtotal
          : cartItems.fold<double>(0, (sum, item) => sum + item.total);

      final calculatedTotal =
          totalAmount ?? (calculatedSubtotal + deliveryCharge + gstAmount);

      final now = DateTime.now();
      final orderId =
          'order-${now.millisecondsSinceEpoch}-${(1000 + (now.microsecond % 9000))}';

      final orderData = {
        'id': orderId,
        'shopId': shopId,
        'shop_id': shopId,
        'userId': userId,
        'user_id': userId,
        'customerName': customerName,
        'customer_name': customerName,
        'customerPhone': customerPhone,
        'customer_phone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'delivery_address': deliveryAddress,
        'customer_address': deliveryAddress,
        'items': items.map((item) => item.toMap()).toList(),
        'subtotal': calculatedSubtotal,
        'deliveryCharge': deliveryCharge,
        'delivery_charge': deliveryCharge,
        'gstAmount': gstAmount,
        'gst_amount': gstAmount,
        'totalAmount': calculatedTotal,
        'total_amount': calculatedTotal,
        'status': 'new',
        'paymentId': paymentId,
        'payment_id': paymentId,
        'isTestOrder': isTestOrder,
        'is_test_order': isTestOrder,
        'customerLatitude': customerLatitude,
        'customerLongitude': customerLongitude,
        'delivery_coordinates': {
          'lat': customerLatitude ?? 27.5706,
          'lng': customerLongitude ?? 77.6593,
        },
        'paymentMethod': paymentMethod.value,
        'payment_method': paymentMethod.value,
        'cashStatus': paymentMethod == PaymentMethod.online
            ? CashStatus.none.value
            : CashStatus.pending.value,
        'cash_status': paymentMethod == PaymentMethod.online
            ? 'collected'
            : 'pending',
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      };

      await _supabase.createOrder(orderData);
      return orderId;
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  // Get order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final data = await _supabase.getOrder(orderId);
      if (data != null) {
        return OrderModel.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }

  // Stream single order for real-time tracking
  Stream<OrderModel?> orderStream(String orderId) {
    return _supabase.streamOrder(orderId).map((data) {
      if (data == null) return null;
      return OrderModel.fromMap(data);
    });
  }

  // Stream orders for a specific shop
  Stream<List<OrderModel>> getOrdersForShop(String shopId, {OrderStatus? status, int? limit}) {
    return _supabase.client
        .from(SupabaseConfig.ordersTable)
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .map((records) {
          var orders = records.map((data) => OrderModel.fromMap(data)).toList();
          if (status != null) {
            orders = orders.where((o) => o.status == status).toList();
          }
          orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          if (limit != null && orders.length > limit) {
            orders = orders.take(limit).toList();
          }
          return orders;
        })
        .handleError((_) => <OrderModel>[]);
  }

  // Stream orders for a user
  Stream<List<OrderModel>> getUserOrders(String userId) {
    return getOrdersForUser(userId);
  }

  Stream<List<OrderModel>> getOrdersForUser(String userId) {
    return _supabase.client
        .from(SupabaseConfig.ordersTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((records) {
          final orders = records.map((data) => OrderModel.fromMap(data)).toList();
          orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          return orders;
        })
        .handleError((_) => <OrderModel>[]);
  }

  // Stream all orders
  Stream<List<OrderModel>> getAllOrders({int? limit}) {
    return _supabase.client
        .from(SupabaseConfig.ordersTable)
        .stream(primaryKey: ['id'])
        .map((records) {
          var orders = records.map((data) => OrderModel.fromMap(data)).toList();
          orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          if (limit != null && orders.length > limit) {
            orders = orders.take(limit).toList();
          }
          return orders;
        })
        .handleError((_) => <OrderModel>[]);
  }

  // Stream kitchen orders (new or preparing)
  Stream<List<OrderModel>> getKitchenOrders([String? shopId]) {
    var stream = _supabase.client.from(SupabaseConfig.ordersTable).stream(primaryKey: ['id']);
    if (shopId != null && shopId.isNotEmpty) {
      stream = stream.eq('shop_id', shopId);
    }
    return stream.map((records) {
      final orders = records
          .map((data) => OrderModel.fromMap(data))
          .where((o) => o.status == OrderStatus.newOrder || o.status == OrderStatus.preparing)
          .toList();
      orders.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
      return orders;
    }).handleError((_) => <OrderModel>[]);
  }

  // Stream delivery orders
  Stream<List<OrderModel>> getDeliveryOrders([String? shopId]) {
    var stream = _supabase.client.from(SupabaseConfig.ordersTable).stream(primaryKey: ['id']);
    if (shopId != null && shopId.isNotEmpty) {
      stream = stream.eq('shop_id', shopId);
    }
    return stream.map((records) {
      final orders = records
          .map((data) => OrderModel.fromMap(data))
          .where((o) =>
              o.status == OrderStatus.readyForPickup ||
              o.status == OrderStatus.outForDelivery)
          .toList();
      orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return orders;
    }).handleError((_) => <OrderModel>[]);
  }

  // Stream delivery orders for multi-shop
  Stream<List<OrderModel>> getDeliveryOrdersMultiShop(List<String> shopIds) {
    return _supabase.client
        .from(SupabaseConfig.ordersTable)
        .stream(primaryKey: ['id'])
        .map((records) {
          final orders = records
              .where((r) => shopIds.contains(r['shop_id'] ?? r['shopId']))
              .map((data) => OrderModel.fromMap(data))
              .where((o) =>
                  o.status == OrderStatus.readyForPickup ||
                  o.status == OrderStatus.outForDelivery)
              .toList();
          orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          return orders;
        })
        .handleError((_) => <OrderModel>[]);
  }

  // Stream completed orders
  Stream<List<OrderModel>> getCompletedOrders([
    String? shopId,
    String? deliveryStaffId,
    DateTime? startDate,
    DateTime? endDate,
  ]) {
    var stream = _supabase.client.from(SupabaseConfig.ordersTable).stream(primaryKey: ['id']);
    if (shopId != null && shopId.isNotEmpty) {
      stream = stream.eq('shop_id', shopId);
    }
    return stream.map((records) {
      var orders = records
          .map((data) => OrderModel.fromMap(data))
          .where((o) => o.status == OrderStatus.completed)
          .toList();
      if (deliveryStaffId != null) {
        orders = orders.where((o) => o.collectedBy == deliveryStaffId).toList();
      }
      if (startDate != null) {
        orders = orders.where((o) => o.createdAt != null && o.createdAt!.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        orders = orders.where((o) => o.createdAt != null && o.createdAt!.isBefore(endDate)).toList();
      }
      orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return orders;
    }).handleError((_) => <OrderModel>[]);
  }

  // Stream returned orders
  Stream<List<OrderModel>> getReturnedOrders([String? shopId]) {
    var stream = _supabase.client.from(SupabaseConfig.ordersTable).stream(primaryKey: ['id']);
    if (shopId != null && shopId.isNotEmpty) {
      stream = stream.eq('shop_id', shopId);
    }
    return stream.map((records) {
      final orders = records
          .map((data) => OrderModel.fromMap(data))
          .where((o) => o.status == OrderStatus.returned)
          .toList();
      orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return orders;
    }).handleError((_) => <OrderModel>[]);
  }

  // Stream unsettled cash orders
  Stream<List<OrderModel>> getUnsettledCashOrders([String? shopId]) {
    var stream = _supabase.client.from(SupabaseConfig.ordersTable).stream(primaryKey: ['id']);
    if (shopId != null && shopId.isNotEmpty) {
      stream = stream.eq('shop_id', shopId);
    }
    return stream.map((records) {
      final orders = records
          .map((data) => OrderModel.fromMap(data))
          .where((o) =>
              o.paymentMethod == PaymentMethod.cash &&
              o.cashStatus == CashStatus.collected)
          .toList();
      orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return orders;
    }).handleError((_) => <OrderModel>[]);
  }

  // Orders placed today
  Future<List<OrderModel>> getOrdersToday([String? shopId]) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      var query = _supabase.client.from(SupabaseConfig.ordersTable).select('*');
      if (shopId != null && shopId.isNotEmpty) {
        query = query.eq('shop_id', shopId);
      }
      final data = await query;
      final orders = List<Map<String, dynamic>>.from(data)
          .map((d) => OrderModel.fromMap(d))
          .where((o) => o.createdAt != null && o.createdAt!.isAfter(startOfDay))
          .toList();
      return orders;
    } catch (_) {
      return [];
    }
  }

  // Update order status
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? deliveryStaffId,
    String? notes,
  }) async {
    try {
      final extraFields = <String, dynamic>{};
      if (deliveryStaffId != null) extraFields['delivery_staff_id'] = deliveryStaffId;
      if (notes != null) extraFields['notes'] = notes;

      await _supabase.updateOrderStatus(orderId, status.value, extraFields: extraFields);
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  // Delete order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _supabase.client
          .from(SupabaseConfig.ordersTable)
          .delete()
          .eq('id', orderId);
    } catch (e) {
      print('Error deleting order: $e');
      rethrow;
    }
  }

  // Stream cash transactions
  Stream<List<CashTransactionModel>> getCashTransactions({
    String? shopId,
    String? deliveryStaffId,
    String? userId,
    CashTransactionType? type,
  }) {
    var stream = _supabase.client
        .from('foody_cash_transactions')
        .stream(primaryKey: ['id']);

    if (shopId != null && shopId.isNotEmpty) {
      stream = stream.eq('shop_id', shopId);
    }

    final targetUser = userId ?? deliveryStaffId;

    return stream.map((records) {
      var list = records.map((data) => CashTransactionModel.fromMap(data)).toList();
      if (targetUser != null) {
        list = list.where((t) => t.userId == targetUser).toList();
      }
      if (type != null) {
        list = list.where((t) => t.type == type).toList();
      }
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    }).handleError((_) => <CashTransactionModel>[]);
  }

  Stream<List<CashTransactionModel>> streamCashTransactions({
    String? deliveryStaffId,
    String? userId,
    CashTransactionType? type,
    int limit = 50,
  }) {
    return getCashTransactions(deliveryStaffId: deliveryStaffId, userId: userId, type: type);
  }

  // Collect cash (delivery completed)
  Future<void> collectCash(
    String orderId,
    String deliveryStaffId,
    String deliveryStaffName, [
    double? amount,
    String? notes,
  ]) async {
    try {
      await _supabase.client
          .from(SupabaseConfig.ordersTable)
          .update({
            'status': 'completed',
            'cash_status': 'collected',
            'collected_by': deliveryStaffId,
            'cash_collected_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      print('Error collecting cash: $e');
    }
  }

  Future<void> markCashCollected({
    required String orderId,
    required String deliveryStaffId,
    required String deliveryStaffName,
    required double amount,
    String? notes,
  }) async {
    return collectCash(orderId, deliveryStaffId, deliveryStaffName, amount, notes);
  }

  // Settle single cash order
  Future<void> settleCash(
    String orderId,
    String settledWithUserId,
    String settledWithUserName, [
    double? amount,
  ]) async {
    try {
      await _supabase.client
          .from(SupabaseConfig.ordersTable)
          .update({
            'cash_status': 'settled',
            'settled_by': settledWithUserId,
            'cash_settled_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      print('Error settling cash: $e');
    }
  }

  Future<void> markCashSettled({
    required String orderId,
    required String settledWithUserId,
    required String settledWithUserName,
    required double amount,
    String? notes,
  }) async {
    return settleCash(orderId, settledWithUserId, settledWithUserName, amount);
  }

  // Settle all cash for a shop
  Future<int> settleAllCashForShop(
    String shopId,
    String settledWithUserId,
    String settledWithUserName,
  ) async {
    try {
      final res = await _supabase.client
          .from(SupabaseConfig.ordersTable)
          .update({
            'cash_status': 'settled',
            'settled_by': settledWithUserId,
            'cash_settled_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('shop_id', shopId)
          .eq('cash_status', 'collected')
          .select('id');
      return (res as List).length;
    } catch (e) {
      print('Error settling all cash: $e');
      return 0;
    }
  }

  // Delete a cash transaction
  Future<void> deleteCashTransaction(String transactionId) async {
    try {
      await _supabase.client
          .from('foody_cash_transactions')
          .delete()
          .eq('id', transactionId);
    } catch (_) {}
  }

  // Mark order as returned
  Future<void> markOrderAsReturned(String orderId, String reason) async {
    try {
      await _supabase.client
          .from(SupabaseConfig.ordersTable)
          .update({
            'status': 'returned',
            'return_reason': reason,
            'returned_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      print('Error marking order as returned: $e');
    }
  }

  // Log contact attempt
  Future<void> logContactAttempt(String orderId) async {
    try {
      await _supabase.client
          .from(SupabaseConfig.ordersTable)
          .update({
            'is_unreachable': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (_) {}
  }

  // Get order statistics for shop/owner
  Future<Map<String, dynamic>> getOrderStats([String? shopId, String period = 'week']) async {
    try {
      var query = _supabase.client.from(SupabaseConfig.ordersTable).select('*');
      if (shopId != null && shopId.isNotEmpty) {
        query = query.eq('shop_id', shopId);
      }
      final data = await query;
      final orders = List<Map<String, dynamic>>.from(data);

      double totalSales = 0;
      int completed = 0;
      int active = 0;
      int cancelled = 0;

      for (final o in orders) {
        final st = o['status']?.toString() ?? '';
        final amt = ((o['total_amount'] ?? o['totalAmount'] ?? 0) as num).toDouble();
        if (st == 'completed') {
          completed++;
          totalSales += amt;
        } else if (['new', 'preparing', 'ready_for_pickup', 'out_for_delivery'].contains(st)) {
          active++;
        } else if (st == 'cancelled') {
          cancelled++;
        }
      }

      return {
        'totalOrders': orders.length,
        'completedOrders': completed,
        'activeOrders': active,
        'cancelledOrders': cancelled,
        'totalRevenue': totalSales,
      };
    } catch (e) {
      return {
        'totalOrders': 0,
        'completedOrders': 0,
        'activeOrders': 0,
        'cancelledOrders': 0,
        'totalRevenue': 0.0,
      };
    }
  }

  // Get delivery statistics
  Future<Map<String, dynamic>> getDeliveryStats([
    String? deliveryStaffId,
    String? shopId,
  ]) async {
    try {
      var query = _supabase.client.from(SupabaseConfig.ordersTable).select('*');
      if (shopId != null && shopId.isNotEmpty) {
        query = query.eq('shop_id', shopId);
      }
      final data = await query;
      final orders = List<Map<String, dynamic>>.from(data);

      int deliveredToday = 0;
      double cashInHand = 0.0;
      int activeDeliveries = 0;

      for (final o in orders) {
        final st = o['status']?.toString() ?? '';
        final cs = o['cash_status']?.toString() ?? '';
        final amt = ((o['total_amount'] ?? o['totalAmount'] ?? 0) as num).toDouble();

        if (st == 'out_for_delivery') {
          activeDeliveries++;
        }
        if (st == 'completed') {
          deliveredToday++;
        }
        if (cs == 'collected') {
          cashInHand += amt;
        }
      }

      return {
        'deliveredToday': deliveredToday,
        'cashInHand': cashInHand,
        'activeDeliveries': activeDeliveries,
      };
    } catch (e) {
      return {
        'deliveredToday': 0,
        'cashInHand': 0.0,
        'activeDeliveries': 0,
      };
    }
  }
}
