import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  newOrder,
  preparing,
  readyForPickup,
  outForDelivery,
  completed,
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
      default:
        return OrderStatus.newOrder;
    }
  }
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
  final double totalAmount;
  final OrderStatus status;
  final String? paymentId;
  final bool isTestOrder;
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
    required this.totalAmount,
    this.status = OrderStatus.newOrder,
    this.paymentId,
    this.isTestOrder = false,
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
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: OrderStatusExtension.fromString(data['status']),
      paymentId: data['paymentId'],
      isTestOrder: data['isTestOrder'] ?? false,
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
      'totalAmount': totalAmount,
      'status': status.value,
      'paymentId': paymentId,
      'isTestOrder': isTestOrder,
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
    double? totalAmount,
    OrderStatus? status,
    String? paymentId,
    bool? isTestOrder,
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
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      isTestOrder: isTestOrder ?? this.isTestOrder,
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
}
