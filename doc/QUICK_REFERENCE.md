# 🔔 Custom Notification Sounds - Quick Reference

## 📋 Quick Commands

```bash
# 1. Add sound files to assets
cp your_sounds/*.mp3 assets/sounds/

# 2. Setup Android (automated)
./setup_notification_sounds.sh

# 3. Convert for iOS
afconvert -f caff -d LEI16@44100 -c 1 assets/sounds/owner_notification.mp3 owner_notification.caf
afconvert -f caff -d LEI16@44100 -c 1 assets/sounds/kitchen_notification.mp3 kitchen_notification.caf
afconvert -f caff -d LEI16@44100 -c 1 assets/sounds/delivery_notification.mp3 delivery_notification.caf

# 4. Rebuild
flutter clean && flutter pub get && flutter build apk
```

## 🎵 Required Sound Files

| File Name | Role | Platform | Location |
|-----------|------|----------|----------|
| `owner_notification.mp3` | Owner | Android | `android/app/src/main/res/raw/` |
| `kitchen_notification.mp3` | Kitchen | Android | `android/app/src/main/res/raw/` |
| `delivery_notification.mp3` | Delivery | Android | `android/app/src/main/res/raw/` |
| `owner_notification.caf` | Owner | iOS | `ios/Runner/` (via Xcode) |
| `kitchen_notification.caf` | Kitchen | iOS | `ios/Runner/` (via Xcode) |
| `delivery_notification.caf` | Delivery | iOS | `ios/Runner/` (via Xcode) |

## 💻 Code Snippets

### Import
```dart
import 'package:foody_vrinda/services/notification_service.dart';
import 'package:foody_vrinda/models/user_model.dart';
```

### Initialize (in main.dart)
```dart
await NotificationService().initialize();
await NotificationService().requestPermissions();
```

### Send Notification
```dart
// Owner
await NotificationService().showNewOrderNotification(
  orderId: orderId,
  customerName: name,
  amount: total,
  userRole: UserRole.owner,
);

// Kitchen
await NotificationService().showNewOrderNotification(
  orderId: orderId,
  customerName: name,
  amount: total,
  userRole: UserRole.kitchen,
);

// Delivery
await NotificationService().showReadyForDeliveryNotification(
  orderId: orderId,
  customerName: name,
  address: address,
  userRole: UserRole.delivery,
);
```

## 📂 File Locations

```
assets/sounds/              ← Put MP3 files here first
android/.../res/raw/        ← Auto-copied by script
ios/Runner/                 ← Add CAF files via Xcode
```

## 🔗 Documentation Links

| Document | Purpose |
|----------|---------|
| `IMPLEMENTATION_SUMMARY.md` | 📊 What was implemented |
| `NOTIFICATION_SOUNDS_GUIDE.md` | 📚 Complete setup guide |
| `INTEGRATION_GUIDE.md` | 🔧 How to integrate into code |
| `NOTIFICATION_FLOW_DIAGRAM.txt` | 📈 Visual flow diagram |
| `android/NOTIFICATION_SOUNDS_SETUP.md` | 🤖 Android setup |
| `ios/NOTIFICATION_SOUNDS_SETUP.md` | 🍎 iOS setup |
| `lib/examples/notification_usage_example.dart` | 💡 Code examples |

## Role-Sound Mapping

| User Role | Sound File | When Triggered |
|-----------|------------|----------------|
| 👔 Owner | `owner_notification` | New order created |
| 👨‍🍳 Kitchen | `kitchen_notification` | New order created |
| 🚚 Delivery | `delivery_notification` | Order ready for delivery |
| 👤 Customer | System default | Order status updates |

## ⚡ Common Issues & Fixes

| Problem | Solution |
|---------|----------|
| Sound not playing | Check file names, rebuild app |
| Build error | Run `flutter clean && flutter pub get` |
| iOS no sound | Check silent mode, verify Xcode integration |
| Android no sound | Verify files in `res/raw/`, check permissions |

## ✅ Testing Checklist

- [ ] Sound files added to `assets/sounds/`
- [ ] Android setup completed (script run)
- [ ] iOS CAF files added to Xcode
- [ ] App rebuilt and installed
- [ ] Tested with owner account
- [ ] Tested with kitchen account
- [ ] Tested with delivery account
- [ ] Verified background notifications work
- [ ] Checked notification permissions

## 🚀 Next Steps

1. **Get 3 sound files** (MP3, 1-3 seconds each)
2. **Run setup script**: `./setup_notification_sounds.sh`
3. **For iOS**: Convert to CAF and add via Xcode
4. **Integrate**: Follow `INTEGRATION_GUIDE.md`
5. **Test**: Build and test with different roles

## 📞 Where Notifications Are Sent

```
Order Created
  └─► Owner (owner_notification)
  └─► Kitchen (kitchen_notification)

Order Ready
  └─► Delivery Staff (delivery_notification)

Status Update
  └─► Customer (system default)
```

## 🎨 Sound Requirements

- **Format**: MP3 (Android), CAF (iOS)
- **Duration**: 1-3 seconds recommended
- **Size**: < 100KB recommended
- **Sample Rate**: 44.1kHz
- **Channels**: Mono preferred

## 🔍 Free Sound Resources

- [Freesound.org](https://freesound.org)
- [Zapsplat.com](https://www.zapsplat.com)
- [Notification Sounds](https://notificationsounds.com)

---

**Quick Refs**: 
- Main Guide: `NOTIFICATION_SOUNDS_GUIDE.md`
- Integration: `INTEGRATION_GUIDE.md`
- Examples: `lib/examples/notification_usage_example.dart`
