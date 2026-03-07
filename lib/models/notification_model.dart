import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return NotificationModel(id: doc.id, userId: '', title: '', message: '');
    }

    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: NotificationTypeExtension.fromString(data['type']),
      orderId: data['orderId'],
      shopId: data['shopId'],
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.value,
      'orderId': orderId,
      'shopId': shopId,
      'isRead': isRead,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
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
