import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'kitchen_alarm_service.dart';
import 'delivery_alarm_service.dart';

/// Manages real-time order listeners and triggers role-tailored notifications and alarms for staff
class OrderNotificationManager {
  static final OrderNotificationManager _instance =
      OrderNotificationManager._internal();
  factory OrderNotificationManager() => _instance;
  OrderNotificationManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  final Map<String, OrderStatus> _knownOrderStatusMap = {};
  bool _isFirstLoad = true;
  UserRole? _currentUserRole;
  String? _currentShopId;
  String? _currentUserId;

  /// Start listening for new orders based on user role
  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
  }

  Future<void> startListening({
    required UserRole userRole,
    String? shopId,
    String? userId,
  }) async {
    // Optimization: Skip restart if we are already listening for the same role/shop/user
    if (_ordersSubscription != null &&
        _currentUserRole == userRole &&
        _currentShopId == shopId &&
        _currentUserId == userId) {
      return;
    }

    // Stop any existing listener
    await stopListening();

    _currentUserRole = userRole;
    _currentShopId = shopId;
    _currentUserId = userId;
    _isFirstLoad = true;
    _knownOrderStatusMap.clear();

    // Initialize notification service
    await _initNotifications();

    // Build query - listen to recent orders only (last 24 hours)
    Query<Map<String, dynamic>> query = _firestore.collection('orders');

    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    query = query.where(
      'createdAt',
      isGreaterThan: Timestamp.fromDate(yesterday),
    );

    _ordersSubscription = query.snapshots().listen(
      (snapshot) => _handleOrdersSnapshot(snapshot, shopId, userRole, userId),
      onError: (error) {
        debugPrint('OrderNotificationManager Error: $error');
      },
    );
  }

  void _handleOrdersSnapshot(
    QuerySnapshot snapshot,
    String? shopId,
    UserRole userRole,
    String? userId,
  ) {
    var docs = snapshot.docs;

    // Filter by shopId for owner/kitchen
    if ((userRole == UserRole.owner || userRole == UserRole.kitchen) &&
        shopId != null) {
      docs = docs
          .where((doc) => (doc.data() as Map?)?.containsKey('shopId') == true)
          .where((doc) => (doc.data() as Map)['shopId'] == shopId)
          .toList();
    }

    // Filter for customer role (only listen to this customer's orders)
    if (userRole == UserRole.customer && userId != null) {
      docs = docs
          .where((doc) => (doc.data() as Map?)?.containsKey('userId') == true)
          .where((doc) => (doc.data() as Map)['userId'] == userId)
          .toList();
    }

    final currentOrders = <String, OrderModel>{};
    for (final doc in docs) {
      try {
        final order = OrderModel.fromFirestore(doc);
        currentOrders[order.id] = order;
      } catch (e) {
        debugPrint('Error parsing order ${doc.id}: $e');
      }
    }

    if (_isFirstLoad) {
      // On first load, record existing order statuses without sounding alarm
      for (final entry in currentOrders.entries) {
        _knownOrderStatusMap[entry.key] = entry.value.status;
      }
      _isFirstLoad = false;
      return;
    }

    // Process each order for additions or status transitions
    for (final entry in currentOrders.entries) {
      final orderId = entry.key;
      final order = entry.value;
      final oldStatus = _knownOrderStatusMap[orderId];
      final newStatus = order.status;

      if (oldStatus == null) {
        // Brand new order arrived
        _handleNewOrderArrival(order, userRole);
      } else if (oldStatus != newStatus) {
        // Status transitioned
        _handleOrderStatusTransition(order, oldStatus, newStatus, userRole);
      }

      // Update known status
      _knownOrderStatusMap[orderId] = newStatus;
    }

    // Clean up orders that were deleted
    _knownOrderStatusMap.removeWhere((id, _) => !currentOrders.containsKey(id));
  }

  void _handleNewOrderArrival(OrderModel order, UserRole userRole) {
    if (order.status == OrderStatus.newOrder) {
      // Kitchen / Owner / Developer alerts
      if (userRole == UserRole.owner ||
          userRole == UserRole.kitchen ||
          userRole == UserRole.developer) {
        _notificationService.showNewOrderNotification(
          orderId: order.id,
          customerName: order.customerName,
          amount: order.totalAmount,
          userRole: userRole,
        );
        KitchenAlarmService().triggerAlarm(order.id);
      }
    } else if (order.status == OrderStatus.readyForPickup) {
      // Delivery / Owner / Developer alerts
      if (userRole == UserRole.delivery ||
          userRole == UserRole.owner ||
          userRole == UserRole.developer) {
        _notificationService.showReadyForDeliveryNotification(
          orderId: order.id,
          customerName: order.customerName,
          address: order.deliveryAddress,
          userRole: userRole,
        );
        DeliveryAlarmService().triggerAlarm(order.id);
      }
    }
  }

  void _handleOrderStatusTransition(
    OrderModel order,
    OrderStatus oldStatus,
    OrderStatus newStatus,
    UserRole userRole,
  ) {
    // 1. Auto-silence / acknowledge alarms based on progression
    if (newStatus == OrderStatus.preparing) {
      KitchenAlarmService().acknowledgeOrder(order.id);
      
      if (userRole == UserRole.customer) {
        _notificationService.showOrderStatusNotification(
          orderId: order.id,
          status: 'Preparing',
          message: 'The kitchen is preparing your sacred Satvik meal in pure desi ghee.',
          userRole: userRole,
        );
      }
    } else if (newStatus == OrderStatus.readyForPickup) {
      KitchenAlarmService().acknowledgeOrder(order.id);

      // Trigger delivery alert
      if (userRole == UserRole.delivery ||
          userRole == UserRole.owner ||
          userRole == UserRole.developer) {
        _notificationService.showReadyForDeliveryNotification(
          orderId: order.id,
          customerName: order.customerName,
          address: order.deliveryAddress,
          userRole: userRole,
        );
        DeliveryAlarmService().triggerAlarm(order.id);
      } else if (userRole == UserRole.customer) {
        _notificationService.showOrderStatusNotification(
          orderId: order.id,
          status: 'Ready',
          message: 'Your prasad is packed and waiting for Sarathi pickup.',
          userRole: userRole,
        );
      }
    } else if (newStatus == OrderStatus.outForDelivery) {
      DeliveryAlarmService().acknowledgeOrder(order.id);
      KitchenAlarmService().acknowledgeOrder(order.id);

      if (userRole == UserRole.customer) {
        _notificationService.showOrderStatusNotification(
          orderId: order.id,
          status: 'Out for Delivery',
          message: 'Your Sarathi rider is on the way with your warm meal!',
          userRole: userRole,
        );
      }
    } else if (newStatus == OrderStatus.completed) {
      DeliveryAlarmService().acknowledgeOrder(order.id);
      KitchenAlarmService().acknowledgeOrder(order.id);

      if (userRole == UserRole.customer) {
        _notificationService.showOrderStatusNotification(
          orderId: order.id,
          status: 'Delivered',
          message: 'Your prasad has been delivered safely. Radhe Radhe!',
          userRole: userRole,
        );
      }
    } else if (newStatus == OrderStatus.cancelled || newStatus == OrderStatus.returned) {
      DeliveryAlarmService().acknowledgeOrder(order.id);
      KitchenAlarmService().acknowledgeOrder(order.id);
    }
  }

  /// Stop listening for orders
  Future<void> stopListening() async {
    await _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _knownOrderStatusMap.clear();
    _isFirstLoad = true;
    _currentUserRole = null;
    _currentShopId = null;
    _currentUserId = null;
  }

  /// Check if currently listening
  bool get isListening => _ordersSubscription != null;

  /// Get current user role
  UserRole? get currentUserRole => _currentUserRole;
}
