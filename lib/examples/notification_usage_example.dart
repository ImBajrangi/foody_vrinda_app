import 'package:foody_vrinda/services/notification_service.dart';
import 'package:foody_vrinda/models/user_model.dart';

/// Example usage of NotificationService with role-based custom sounds
///
/// This file demonstrates how to use the updated notification service
/// to send notifications with different sounds based on user roles.

class NotificationUsageExample {
  final NotificationService _notificationService = NotificationService();

  /// Example 1: Send new order notification to owner
  Future<void> notifyOwnerOfNewOrder({
    required String orderId,
    required String customerName,
    required double amount,
    String? shopName,
  }) async {
    await _notificationService.showNewOrderNotification(
      orderId: orderId,
      customerName: customerName,
      amount: amount,
      shopName: shopName,
      userRole: UserRole.owner, // Owner will hear owner_notification.mp3
    );
  }

  /// Example 2: Send new order notification to kitchen staff
  Future<void> notifyKitchenOfNewOrder({
    required String orderId,
    required String customerName,
    required double amount,
  }) async {
    await _notificationService.showNewOrderNotification(
      orderId: orderId,
      customerName: customerName,
      amount: amount,
      userRole:
          UserRole.kitchen, // Kitchen staff will hear kitchen_notification.mp3
    );
  }

  /// Example 3: Send ready for delivery notification to delivery staff
  Future<void> notifyDeliveryStaffOfReadyOrder({
    required String orderId,
    required String customerName,
    required String address,
  }) async {
    await _notificationService.showReadyForDeliveryNotification(
      orderId: orderId,
      customerName: customerName,
      address: address,
      userRole: UserRole
          .delivery, // Delivery staff will hear delivery_notification.mp3
    );
  }

  /// Example 4: Send order status update to customer
  Future<void> notifyCustomerOfOrderStatus({
    required String orderId,
    required String status,
    required String message,
  }) async {
    await _notificationService.showOrderStatusNotification(
      orderId: orderId,
      status: status,
      message: message,
      userRole: UserRole.customer, // Customer will hear default system sound
    );
  }

  /// Example 5: Complete order workflow with multiple role notifications
  Future<void> completeOrderWorkflow({
    required String orderId,
    required String customerName,
    required double amount,
    required String address,
    String? shopName,
  }) async {
    // Step 1: Notify owner of new order
    await notifyOwnerOfNewOrder(
      orderId: orderId,
      customerName: customerName,
      amount: amount,
      shopName: shopName,
    );

    // Step 2: Notify kitchen staff to prepare
    await notifyKitchenOfNewOrder(
      orderId: orderId,
      customerName: customerName,
      amount: amount,
    );

    // Simulate waiting for order preparation
    await Future.delayed(Duration(seconds: 2));

    // Step 3: Notify delivery staff when ready
    await notifyDeliveryStaffOfReadyOrder(
      orderId: orderId,
      customerName: customerName,
      address: address,
    );

    // Step 4: Notify customer of delivery
    await notifyCustomerOfOrderStatus(
      orderId: orderId,
      status: 'out_for_delivery',
      message: 'Your order is out for delivery!',
    );
  }

  /// Example 6: Initialize notification service (call once at app start)
  Future<void> initializeNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
  }

  /// Example 7: Dynamic role-based notification
  Future<void> sendNotificationBasedOnUserRole({
    required UserModel user,
    required String orderId,
    required String message,
  }) async {
    switch (user.role) {
      case UserRole.owner:
        await _notificationService.showNotification(
          title: '💼 Owner Alert',
          body: message,
          payload: orderId,
          userRole: UserRole.owner,
        );
        break;
      case UserRole.kitchen:
        await _notificationService.showNotification(
          title: '👨‍🍳 Kitchen Alert',
          body: message,
          payload: orderId,
          userRole: UserRole.kitchen,
        );
        break;
      case UserRole.delivery:
        await _notificationService.showNotification(
          title: '🚚 Delivery Alert',
          body: message,
          payload: orderId,
          userRole: UserRole.delivery,
        );
        break;
      default:
        await _notificationService.showNotification(
          title: '📱 Notification',
          body: message,
          payload: orderId,
          userRole: user.role,
        );
    }
  }
}

/// Integration example with order service
///
/// This shows how to integrate the notification service when creating orders
class OrderServiceIntegrationExample {
  final NotificationService _notificationService = NotificationService();

  Future<void> createOrderWithNotifications({
    required String orderId,
    required String customerName,
    required double amount,
    required String shopId,
    required List<UserModel> shopStaff, // List of staff to notify
  }) async {
    // After creating the order in Firestore...

    // Notify all relevant staff members
    for (var staff in shopStaff) {
      if (staff.role == UserRole.owner || staff.role == UserRole.kitchen) {
        await _notificationService.showNewOrderNotification(
          orderId: orderId,
          customerName: customerName,
          amount: amount,
          userRole: staff.role,
        );
      }
    }
  }
}
