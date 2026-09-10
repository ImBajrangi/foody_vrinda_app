import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'kitchen_alarm_service.dart';
import 'delivery_alarm_service.dart';
import 'supabase_service.dart';
import '../config/supabase_config.dart';

/// Manages real-time order listeners and triggers role-tailored notifications and alarms for staff
class OrderNotificationManager {
  static final OrderNotificationManager _instance =
      OrderNotificationManager._internal();
  factory OrderNotificationManager() => _instance;
  OrderNotificationManager._internal();

  final SupabaseService _supabase = SupabaseService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  final Map<String, OrderStatus> _knownOrderStatusMap = {};
  bool _isFirstLoad = true;
  UserRole? _currentUserRole;
  String? _currentShopId;
  String? _currentUserId;

  /// Start listening for new orders based on user role
  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
    await KitchenAlarmService().initialize();
    await DeliveryAlarmService().initialize();
  }

  Future<void> startListening({
    required UserRole userRole,
    String? shopId,
    String? userId,
  }) async {
    if (_ordersSubscription != null &&
        _currentUserRole == userRole &&
        _currentShopId == shopId &&
        _currentUserId == userId) {
      return;
    }

    await stopListening();

    _currentUserRole = userRole;
    _currentShopId = shopId;
    _currentUserId = userId;
    _isFirstLoad = true;
    _knownOrderStatusMap.clear();

    await _initNotifications();

    try {
      var stream = _supabase.client
          .from(SupabaseConfig.ordersTable)
          .stream(primaryKey: ['id']);

      _ordersSubscription = stream.listen(
        (records) => _handleOrdersSnapshot(records, shopId, userRole, userId),
        onError: (error) {
          debugPrint('OrderNotificationManager Supabase Stream Error: $error');
        },
      );
    } catch (e) {
      debugPrint('OrderNotificationManager failed to attach stream: $e');
    }
  }

  void _handleOrdersSnapshot(
    List<Map<String, dynamic>> records,
    String? shopId,
    UserRole userRole,
    String? userId,
  ) {
    var filtered = records;

    // Filter by shopId for owner/kitchen
    if ((userRole == UserRole.owner || userRole == UserRole.kitchen) &&
        shopId != null) {
      filtered = filtered
          .where((r) => (r['shop_id'] == shopId || r['shopId'] == shopId))
          .toList();
    }

    // Filter for customer role
    if (userRole == UserRole.customer && userId != null) {
      filtered = filtered
          .where((r) => (r['user_id'] == userId || r['userId'] == userId))
          .toList();
    }

    final currentOrders = <String, OrderModel>{};
    for (final data in filtered) {
      try {
        final order = OrderModel.fromMap(data);
        currentOrders[order.id] = order;
      } catch (e) {
        debugPrint('Error parsing order ${data['id']}: $e');
      }
    }

    if (_isFirstLoad) {
      for (final entry in currentOrders.entries) {
        _knownOrderStatusMap[entry.key] = entry.value.status;
        final order = entry.value;

        // On initial startup, check for unhandled pending orders
        if (order.status == OrderStatus.newOrder) {
          if (userRole == UserRole.kitchen ||
              userRole == UserRole.owner ||
              userRole == UserRole.developer) {
            KitchenAlarmService().triggerAlarm(order.id);
          }
        } else if (order.status == OrderStatus.readyForPickup) {
          if (userRole == UserRole.delivery ||
              userRole == UserRole.owner ||
              userRole == UserRole.developer) {
            DeliveryAlarmService().triggerAlarm(order.id);
          }
        }
      }
      _isFirstLoad = false;
      return;
    }

    for (final entry in currentOrders.entries) {
      final orderId = entry.key;
      final order = entry.value;
      final oldStatus = _knownOrderStatusMap[orderId];
      final newStatus = order.status;

      if (oldStatus == null) {
        _handleNewOrderArrival(order, userRole);
      } else if (oldStatus != newStatus) {
        _handleOrderStatusTransition(order, oldStatus, newStatus, userRole);
      }

      _knownOrderStatusMap[orderId] = newStatus;
    }

    _knownOrderStatusMap.removeWhere((id, _) => !currentOrders.containsKey(id));
  }

  void _handleNewOrderArrival(OrderModel order, UserRole userRole) {
    if (order.status == OrderStatus.newOrder) {
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
    if (newStatus == OrderStatus.preparing) {
      KitchenAlarmService().acknowledgeOrder(order.id);
      if (userRole == UserRole.customer) {
        _notificationService.showOrderStatusNotification(
          orderId: order.id,
          status: 'Cooking',
          message: 'Preparation in progress',
          userRole: userRole,
        );
      }
    } else if (newStatus == OrderStatus.readyForPickup) {
      KitchenAlarmService().acknowledgeOrder(order.id);
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
          message: 'Packed & awaiting dispatch',
          userRole: userRole,
        );
      }
    } else if (newStatus == OrderStatus.outForDelivery) {
      DeliveryAlarmService().acknowledgeOrder(order.id);
      KitchenAlarmService().acknowledgeOrder(order.id);
      if (userRole == UserRole.customer) {
        _notificationService.showOrderStatusNotification(
          orderId: order.id,
          status: 'Dispatched',
          message: 'Rider is on the way',
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
          message: 'Delivered successfully',
          userRole: userRole,
        );
      }
    } else if (newStatus == OrderStatus.cancelled || newStatus == OrderStatus.returned) {
      DeliveryAlarmService().acknowledgeOrder(order.id);
      KitchenAlarmService().acknowledgeOrder(order.id);
      if (userRole == UserRole.customer) {
        _notificationService.showOrderStatusNotification(
          orderId: order.id,
          status: 'Cancelled',
          message: 'Order has been cancelled',
          userRole: userRole,
        );
      }
    }
  }

  Future<void> stopListening() async {
    await _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _knownOrderStatusMap.clear();
    _isFirstLoad = true;
    _currentUserRole = null;
    _currentShopId = null;
    _currentUserId = null;
  }

  bool get isListening => _ordersSubscription != null;
  UserRole? get currentUserRole => _currentUserRole;
}
