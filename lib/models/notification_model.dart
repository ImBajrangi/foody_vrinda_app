enum NotificationType {
  newOrder,
  orderReady,
  orderCompleted,
  staffAdded,
  general,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.newOrder:
        return 'new_order';
      case NotificationType.orderReady:
        return 'order_ready';
      case NotificationType.orderCompleted:
        return 'order_completed';
      case NotificationType.staffAdded:
        return 'staff_added';
      case NotificationType.general:
        return 'general';
    }
  }

  static NotificationType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'new_order':
        return NotificationType.newOrder;
      case 'order_ready':
        return NotificationType.orderReady;
      case 'order_completed':
        return NotificationType.orderCompleted;
      case 'staff_added':
        return NotificationType.staffAdded;
      default:
        return NotificationType.general;
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String? orderId;
  final String? shopId;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = NotificationType.general,
    this.orderId,
    this.shopId,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> data) {
    DateTime? createdAt;
    if (data['created_at'] != null) {
      createdAt = DateTime.tryParse(data['created_at'].toString());
    } else if (data['createdAt'] != null) {
      createdAt = DateTime.tryParse(data['createdAt'].toString());
    }

    return NotificationModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? data['userId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      type: NotificationTypeExtension.fromString(data['type']?.toString()),
      orderId: data['order_id']?.toString() ?? data['orderId']?.toString(),
      shopId: data['shop_id']?.toString() ?? data['shopId']?.toString(),
      isRead: data['is_read'] ?? data['isRead'] ?? false,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type.value,
      'order_id': orderId,
      'shop_id': shopId,
      'is_read': isRead,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? orderId,
    String? shopId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      orderId: orderId ?? this.orderId,
      shopId: shopId ?? this.shopId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
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
