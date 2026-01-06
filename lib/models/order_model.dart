import 'package:cloud_firestore/cloud_firestore.dart';
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
        return OrderStatus.preparing;
      case 'ready_for_pickup':
        return OrderStatus.readyForPickup;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'completed':
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
      menuItemId: data['menuItemId'] ?? '',
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
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

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return OrderModel(
        id: doc.id,
        shopId: '',
        customerName: '',
        customerPhone: '',
        deliveryAddress: '',
        items: [],
        totalAmount: 0,
      );
    }

    final itemsList = data['items'] as List<dynamic>?;
    final items =
        itemsList
            ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];

    return OrderModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      userId: data['userId'],
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      deliveryAddress: data['deliveryAddress'] ?? '',
      items: items,
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      deliveryCharge: (data['deliveryCharge'] ?? 0.0).toDouble(),
      gstAmount: (data['gstAmount'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: OrderStatusExtension.fromString(data['status']),
      paymentId: data['paymentId'],
      isTestOrder: data['isTestOrder'] ?? false,
      paymentMethod: PaymentMethodExtension.fromString(data['paymentMethod']),
      cashStatus: CashStatusExtension.fromString(data['cashStatus']),
      collectedBy: data['collectedBy'],
      settledBy: data['settledBy'],
      cashCollectedAt: data['cashCollectedAt'] != null
          ? (data['cashCollectedAt'] as Timestamp).toDate()
          : null,
      cashSettledAt: data['cashSettledAt'] != null
          ? (data['cashSettledAt'] as Timestamp).toDate()
          : null,
      returnedAt: data['returnedAt'] != null
          ? (data['returnedAt'] as Timestamp).toDate()
          : null,
      returnReason: data['returnReason'],
      contactAttempts:
          (data['contactAttempts'] as List<dynamic>?)
              ?.map((t) => (t as Timestamp).toDate())
              .toList() ??
          [],
      isUnreachable: data['isUnreachable'] ?? false,
      customerLatitude: (data['customerLatitude'] as num?)?.toDouble(),
      customerLongitude: (data['customerLongitude'] as num?)?.toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'userId': userId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryCharge': deliveryCharge,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
      'status': status.value,
      'paymentId': paymentId,
      'isTestOrder': isTestOrder,
      'paymentMethod': paymentMethod.value,
      'cashStatus': cashStatus.value,
      'collectedBy': collectedBy,
      'settledBy': settledBy,
      'cashCollectedAt': cashCollectedAt != null
          ? Timestamp.fromDate(cashCollectedAt!)
          : null,
      'cashSettledAt': cashSettledAt != null
          ? Timestamp.fromDate(cashSettledAt!)
          : null,
      'returnedAt': returnedAt != null ? Timestamp.fromDate(returnedAt!) : null,
      'returnReason': returnReason,
      'contactAttempts': contactAttempts
          .map((t) => Timestamp.fromDate(t))
          .toList(),
      'isUnreachable': isUnreachable,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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
