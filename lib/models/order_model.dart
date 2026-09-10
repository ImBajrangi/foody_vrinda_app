import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

enum OrderStatus {
  newOrder,
  preparing,
  readyForPickup,
  outForDelivery,
  completed,
  cancelled,
  returned,
}

enum PaymentMethod { cash, online }

enum CashStatus {
  none, // For online payments
  pending, // COD order not yet delivered
  collected, // Delivered and cash collected by delivery staff
  settled, // Cash handed over to owner/shop
}

extension OrderStatusExtension on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.newOrder:
        return 'new';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.readyForPickup:
        return 'ready_for_pickup';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.returned:
        return 'returned';
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.newOrder:
        return 'New';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned to Shop';
    }
  }

  static OrderStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'preparing':
      case 'in_kitchen':
      case 'accepted':
        return OrderStatus.preparing;
      case 'ready_for_pickup':
      case 'readyforpickup':
      case 'ready':
      case 'out_of_kitchen':
      case 'ready_for_dispatch':
        return OrderStatus.readyForPickup;
      case 'out_for_delivery':
      case 'outfordelivery':
      case 'picked_up':
      case 'in_transit':
        return OrderStatus.outForDelivery;
      case 'completed':
      case 'delivered':
      case 'done':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'returned':
        return OrderStatus.returned;
      default:
        return OrderStatus.newOrder;
    }
  }
}

extension PaymentMethodExtension on PaymentMethod {
  String get value => name;
  static PaymentMethod fromString(String? val) =>
      val == 'online' ? PaymentMethod.online : PaymentMethod.cash;
}

extension CashStatusExtension on CashStatus {
  String get value => name;
  static CashStatus fromString(String? val) => CashStatus.values.firstWhere(
    (e) => e.name == val,
    orElse: () => CashStatus.none,
  );
}

class OrderItem {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      menuItemId: (data['menuItemId'] ?? data['menu_item_id'] ?? data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      price: (data['price'] is num ? data['price'] : num.tryParse(data['price']?.toString() ?? '0') ?? 0).toDouble(),
      quantity: (data['quantity'] is int ? data['quantity'] : int.tryParse(data['quantity']?.toString() ?? '1') ?? 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  double get total => price * quantity;

  String get formattedTotal => '₹${total.toStringAsFixed(0)}';
}

class OrderModel {
  final String id;
  final String shopId;
  final String? userId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final List<OrderItem> items;
  final double subtotal; // Sum of item prices
  final double deliveryCharge; // Delivery fee
  final double gstAmount; // GST amount
  final double totalAmount; // subtotal + deliveryCharge + gstAmount
  final OrderStatus status;
  final String? paymentId;
  final bool isTestOrder;
  final PaymentMethod paymentMethod;
  final CashStatus cashStatus;
  final String? collectedBy;
  final String? settledBy;
  final DateTime? cashCollectedAt;
  final DateTime? cashSettledAt;
  final DateTime? returnedAt;
  final String? returnReason;
  final List<DateTime> contactAttempts;
  final bool isUnreachable;
  final double? customerLatitude;
  final double? customerLongitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.id,
    required this.shopId,
    this.userId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.items,
    this.subtotal = 0.0,
    this.deliveryCharge = 0.0,
    this.gstAmount = 0.0,
    required this.totalAmount,
    this.status = OrderStatus.newOrder,
    this.paymentId,
    this.isTestOrder = false,
    this.paymentMethod = PaymentMethod.cash,
    this.cashStatus = CashStatus.pending,
    this.collectedBy,
    this.settledBy,
    this.cashCollectedAt,
    this.cashSettledAt,
    this.returnedAt,
    this.returnReason,
    this.contactAttempts = const [],
    this.isUnreachable = false,
    this.customerLatitude,
    this.customerLongitude,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final orderId = id ?? data['id']?.toString() ?? '';
    final itemsList = data['items'] as List<dynamic>?;
    final items = itemsList
            ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];

    // Parse coordinates
    double? lat;
    double? lng;
    if (data['delivery_coordinates'] != null && data['delivery_coordinates'] is Map) {
      final coords = data['delivery_coordinates'] as Map;
      lat = (coords['lat'] as num?)?.toDouble();
      lng = (coords['lng'] as num?)?.toDouble();
    } else {
      lat = (data['customerLatitude'] ?? data['customer_latitude'] ?? data['lat']) != null
          ? ((data['customerLatitude'] ?? data['customer_latitude'] ?? data['lat']) as num).toDouble()
          : null;
      lng = (data['customerLongitude'] ?? data['customer_longitude'] ?? data['lng']) != null
          ? ((data['customerLongitude'] ?? data['customer_longitude'] ?? data['lng']) as num).toDouble()
          : null;
    }

    // Parse timestamps
    DateTime? createdAt;
    if (data['created_at'] != null) {
      createdAt = DateTime.tryParse(data['created_at'].toString());
    } else if (data['createdAt'] != null) {
      createdAt = DateTime.tryParse(data['createdAt'].toString());
    }

    DateTime? updatedAt;
    if (data['updated_at'] != null) {
      updatedAt = DateTime.tryParse(data['updated_at'].toString());
    } else if (data['updatedAt'] != null) {
      updatedAt = DateTime.tryParse(data['updatedAt'].toString());
    }

    return OrderModel(
      id: orderId,
      shopId: (data['shop_id'] ?? data['shopId'] ?? '').toString(),
      userId: (data['user_id'] ?? data['userId'])?.toString(),
      customerName: (data['customer_name'] ?? data['customerName'] ?? '').toString(),
      customerPhone: (data['customer_phone'] ?? data['customerPhone'] ?? '').toString(),
      deliveryAddress: (data['delivery_address'] ?? data['customer_address'] ?? data['deliveryAddress'] ?? '').toString(),
      items: items,
      subtotal: ((data['subtotal'] ?? 0.0) as num).toDouble(),
      deliveryCharge: ((data['delivery_charge'] ?? data['deliveryCharge'] ?? 0.0) as num).toDouble(),
      gstAmount: ((data['gst_amount'] ?? data['gstAmount'] ?? 0.0) as num).toDouble(),
      totalAmount: ((data['total_amount'] ?? data['totalAmount'] ?? 0.0) as num).toDouble(),
      status: OrderStatusExtension.fromString(data['status']?.toString()),
      paymentId: (data['payment_id'] ?? data['paymentId'])?.toString(),
      isTestOrder: data['is_test_order'] ?? data['isTestOrder'] ?? false,
      paymentMethod: PaymentMethodExtension.fromString(data['payment_method'] ?? data['paymentMethod']),
      cashStatus: CashStatusExtension.fromString(data['cash_status'] ?? data['cashStatus']),
      collectedBy: (data['collected_by'] ?? data['collectedBy'])?.toString(),
      settledBy: (data['settled_by'] ?? data['settledBy'])?.toString(),
      customerLatitude: lat,
      customerLongitude: lng,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'user_id': userId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'delivery_charge': deliveryCharge,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
      'status': status.value,
      'payment_id': paymentId,
      'is_test_order': isTestOrder,
      'payment_method': paymentMethod.value,
      'cash_status': cashStatus.value,
      'collected_by': collectedBy,
      'settled_by': settledBy,
      'cash_collected_at': cashCollectedAt?.toUtc().toIso8601String(),
      'cash_settled_at': cashSettledAt?.toUtc().toIso8601String(),
      'returned_at': returnedAt?.toUtc().toIso8601String(),
      'return_reason': returnReason,
      'is_unreachable': isUnreachable,
      'customer_latitude': customerLatitude,
      'customer_longitude': customerLongitude,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  OrderModel copyWith({
    String? id,
    String? shopId,
    String? userId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryCharge,
    double? gstAmount,
    double? totalAmount,
    OrderStatus? status,
    String? paymentId,
    bool? isTestOrder,
    PaymentMethod? paymentMethod,
    CashStatus? cashStatus,
    String? collectedBy,
    String? settledBy,
    DateTime? cashCollectedAt,
    DateTime? cashSettledAt,
    DateTime? returnedAt,
    String? returnReason,
    List<DateTime>? contactAttempts,
    bool? isUnreachable,
    double? customerLatitude,
    double? customerLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      gstAmount: gstAmount ?? this.gstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      isTestOrder: isTestOrder ?? this.isTestOrder,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashStatus: cashStatus ?? this.cashStatus,
      collectedBy: collectedBy ?? this.collectedBy,
      settledBy: settledBy ?? this.settledBy,
      cashCollectedAt: cashCollectedAt ?? this.cashCollectedAt,
      cashSettledAt: cashSettledAt ?? this.cashSettledAt,
      returnedAt: returnedAt ?? this.returnedAt,
      returnReason: returnReason ?? this.returnReason,
      contactAttempts: contactAttempts ?? this.contactAttempts,
      isUnreachable: isUnreachable ?? this.isUnreachable,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedTotal => '₹${totalAmount.toStringAsFixed(0)}';

  String get itemsSummary {
    return items.map((item) => '${item.quantity}x ${item.name}').join(', ');
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  String get orderNumber {
    if (createdAt != null) {
      return '#${createdAt!.millisecondsSinceEpoch.toString().substring(5)}';
    }
    return '#${id.substring(0, 6).toUpperCase()}';
  }

  String get timeAgo {
    if (createdAt == null) return '';

    final diff = DateTime.now().difference(createdAt!);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get arrivalTime {
    if (createdAt == null) return 'N/A';
    return DateFormat('hh:mm a').format(createdAt!);
  }

  String get importance {
    if (totalAmount >= 500) return 'High';
    if (totalAmount >= 200) return 'Medium';
    return 'Regular';
  }

  Color get importanceColor {
    if (totalAmount >= 500) return const Color(0xFFE53935); // Important Red
    if (totalAmount >= 200) return const Color(0xFFFB8C00); // Orange
    return const Color(0xFF43A047); // Green
  }

  String get statusMessage {
    switch (status) {
      case OrderStatus.newOrder:
        return 'Order Received';
      case OrderStatus.preparing:
        return 'Chef is Cooking';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Order Delivered';
      case OrderStatus.cancelled:
        return 'Order Cancelled';
      case OrderStatus.returned:
        return 'Returned to Shop';
    }
  }

  String get statusDetails {
    switch (status) {
      case OrderStatus.newOrder:
        return 'The shop has received your order and will start preparing it soon.';
      case OrderStatus.preparing:
        return 'Your meal is being prepared with care in the kitchen.';
      case OrderStatus.readyForPickup:
        return 'Great news! Your order is ready. A delivery partner is being assigned.';
      case OrderStatus.outForDelivery:
        return 'Your order is on the way! Please be ready to receive it.';
      case OrderStatus.completed:
        return 'Enjoy your meal! Thank you for ordering with us.';
      case OrderStatus.cancelled:
        return 'This order was cancelled. Please contact the shop if you have questions.';
      case OrderStatus.returned:
        return 'The order could not be delivered and has been returned to the shop.';
    }
  }
}
