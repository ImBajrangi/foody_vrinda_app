# Integration Guide: Adding Notifications to Order Service

This guide shows how to integrate the custom notification sounds into your existing order workflow.

## Step 1: Update Order Service

Add notification service to `lib/services/order_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';
import '../models/user_model.dart';
import './notification_service.dart';  // Add this import

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();  // Add this

  // ... existing code ...
}
```

## Step 2: Notify Staff When Order is Created

Modify the `createOrder` method to send notifications:

```dart
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
  // ... existing order creation code ...

  // After successfully creating the order:
  final orderId = orderRef.id;
  
  // Get shop staff to notify
  await _notifyShopStaff(
    orderId: orderId,
    shopId: shopId,
    customerName: customerName,
    totalAmount: totalAmount,
  );

  return orderId;
}

// Add new helper method
Future<void> _notifyShopStaff({
  required String orderId,
  required String shopId,
  required String customerName,
  required double totalAmount,
}) async {
  try {
    // Get all users associated with this shop
    final usersSnapshot = await _firestore
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .get();

    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final userRole = UserRoleExtension.fromString(userData['role']);

      // Notify owner and kitchen staff about new orders
      if (userRole == UserRole.owner || userRole == UserRole.kitchen) {
        await _notificationService.showNewOrderNotification(
          orderId: orderId,
          customerName: customerName,
          amount: totalAmount,
          userRole: userRole,  // This triggers role-specific sound!
        );
      }
    }
  } catch (e) {
    print('Error notifying staff: $e');
    // Don't fail the order if notification fails
  }
}
```

## Step 3: Notify Delivery Staff When Order is Ready

Modify the `updateOrderStatus` method:

```dart
Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
  await _firestore.collection('orders').doc(orderId).update({
    'status': status.value,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  // If order is ready for delivery, notify delivery staff
  if (status == OrderStatus.ready || status == OrderStatus.outForDelivery) {
    await _notifyDeliveryStaff(orderId);
  }
}

Future<void> _notifyDeliveryStaff(String orderId) async {
  try {
    // Get order details
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) return;

    final orderData = orderDoc.data()!;
    final shopId = orderData['shopId'] as String;
    final customerName = orderData['customerName'] as String;
    final deliveryAddress = orderData['deliveryAddress'] as String;

    // Get delivery staff for this shop
    final deliveryStaffSnapshot = await _firestore
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .where('role', isEqualTo: 'delivery')
        .get();

    // Also check for multi-shop delivery staff
    final multiShopStaffSnapshot = await _firestore
        .collection('users')
        .where('shopIds', arrayContains: shopId)
        .where('role', isEqualTo: 'delivery')
        .get();

    // Notify all delivery staff
    final allDeliveryStaff = [
      ...deliveryStaffSnapshot.docs,
      ...multiShopStaffSnapshot.docs
    ];

    for (var staffDoc in allDeliveryStaff) {
      await _notificationService.showReadyForDeliveryNotification(
        orderId: orderId,
        customerName: customerName,
        address: deliveryAddress,
        userRole: UserRole.delivery,  // Delivery staff custom sound!
      );
    }
  } catch (e) {
    print('Error notifying delivery staff: $e');
  }
}
```

## Step 4: Notify Users of Status Updates

Add customer notifications:

```dart
Future<void> _notifyCustomerOfStatusUpdate({
  required String orderId,
  required String userId,
  required OrderStatus status,
}) async {
  if (userId.isEmpty) return;  // Skip for guest orders

  String message = '';
  switch (status) {
    case OrderStatus.confirmed:
      message = 'Your order has been confirmed and is being prepared';
      break;
    case OrderStatus.preparing:
      message = 'Your order is now being prepared';
      break;
    case OrderStatus.ready:
      message = 'Your order is ready for pickup/delivery';
      break;
    case OrderStatus.outForDelivery:
      message = 'Your order is out for delivery';
      break;
    case OrderStatus.delivered:
      message = 'Your order has been delivered. Enjoy!';
      break;
    default:
      return;
  }

  await _notificationService.showOrderStatusNotification(
    orderId: orderId,
    status: status.value,
    message: message,
    userRole: UserRole.customer,  // Uses default system sound
  );
}

// Call this in updateOrderStatus
Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
  // Get order to find userId
  final orderDoc = await _firestore.collection('orders').doc(orderId).get();
  final orderData = orderDoc.data();
  final userId = orderData?['userId'] as String?;

  // Update status
  await _firestore.collection('orders').doc(orderId).update({
    'status': status.value,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  // Notify customer
  if (userId != null) {
    await _notifyCustomerOfStatusUpdate(
      orderId: orderId,
      userId: userId,
      status: status,
    );
  }

  // Notify delivery staff if ready
  if (status == OrderStatus.ready || status == OrderStatus.outForDelivery) {
    await _notifyDeliveryStaff(orderId);
  }
}
```

## Step 5: Update Cart Screen (Optional)

If you want to play a sound immediately after order placement, update `cart_screen.dart`:

```dart
// After successful order creation
final orderId = await _orderService.createOrder(...);

// Show local notification to user
await NotificationService().showNotification(
  title: '✅ Order Placed Successfully!',
  body: 'Your order #$orderId has been placed',
  payload: orderId,
  userRole: UserRole.customer,
);
```

## Step 6: Initialize Notifications in main.dart

Make sure notifications are initialized when app starts:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  await NotificationService().requestPermissions();
  
  runApp(MyApp());
}
```

## Complete Integration Checklist

- [ ] Add NotificationService import to order_service.dart
- [ ] Add `_notificationService` instance to OrderService class
- [ ] Implement `_notifyShopStaff` method
- [ ] Implement `_notifyDeliveryStaff` method
- [ ] Implement `_notifyCustomerOfStatusUpdate` method
- [ ] Update `createOrder` to call `_notifyShopStaff`
- [ ] Update `updateOrderStatus` to call notification methods
- [ ] Initialize NotificationService in main.dart
- [ ] Add sound files to `assets/sounds/`
- [ ] Add sound files to `android/app/src/main/res/raw/`
- [ ] Add `.caf` sound files to iOS project
- [ ] Test with different user roles
- [ ] Verify custom sounds play for each role

## Testing Workflow

1. **Test Owner Notifications:**
   - Login as owner
   - Create a test order from customer account
   - Verify owner hears custom owner sound

2. **Test Kitchen Notifications:**
   - Login as kitchen staff
   - Create a test order
   - Verify kitchen staff hears custom kitchen sound

3. **Test Delivery Notifications:**
   - Login as delivery staff
   - Mark an order as ready (from owner/kitchen account)
   - Verify delivery staff hears custom delivery sound

4. **Test Customer Notifications:**
   - Place an order as customer
   - Update order status
   - Verify customer hears default system sound

## Notes

- All notification methods are **non-blocking** - they won't fail your order if notification fails
- Notifications work even when app is in background
- Custom sounds only play if sound files are present; otherwise, system default is used
- Each role has a unique notification channel for better organization
- Users can manage notification preferences in device settings

## Next Steps

After integration:
1. Monitor notification logs for any errors
2. Collect feedback from staff on sound preferences
3. Consider adding notification preferences to user profile
4. Implement notification history/read status if needed

## Support

For issues:
- Check `NOTIFICATION_SOUNDS_GUIDE.md` for setup
- Review `lib/examples/notification_usage_example.dart` for examples
- Verify sound files are properly placed
- Check device notification permissions
