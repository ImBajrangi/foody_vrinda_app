# 🔔 Custom Notification Sounds Setup Guide

This guide will help you set up custom notification sounds for different staff roles (Owner, Kitchen, Delivery) in the Foody Vrinda app.

## Overview

The app now supports **role-based custom notification sounds**:
- 🎵 **Owner**: Custom sound for owner notifications
- 👨‍🍳 **Kitchen Staff**: Custom sound for kitchen notifications  
- 🚚 **Delivery Staff**: Custom sound for delivery notifications
- 📱 **Customers**: Default system sound

## Quick Start

### Step 1: Prepare Your Sound Files

1. Get or create 3 short sound files (1-3 seconds recommended)
2. Save them in MP3 format with these exact names:
   - `owner_notification.mp3`
   - `kitchen_notification.mp3`
   - `delivery_notification.mp3`

**Sound Requirements:**
- Format: MP3, OGG, or WAV
- Duration: 1-3 seconds (max 30 seconds for iOS)
- File size: < 100KB recommended
- Sample rate: 44.1kHz recommended

### Step 2: Add Sounds to Assets

Copy your sound files to:
```
assets/sounds/
```

### Step 3: Setup for Android

#### Option A: Automatic (Recommended)
Run the setup script from the project root:
```bash
./setup_notification_sounds.sh
```

#### Option B: Manual
1. Navigate to: `android/app/src/main/res/raw/`
2. Create the `raw` folder if it doesn't exist
3. Copy your MP3 files to this directory

See [android/NOTIFICATION_SOUNDS_SETUP.md](./android/NOTIFICATION_SOUNDS_SETUP.md) for detailed instructions.

### Step 4: Setup for iOS

1. **Convert MP3 to CAF format** (on macOS):
   ```bash
   afconvert -f caff -d LEI16@44100 -c 1 owner_notification.mp3 owner_notification.caf
   afconvert -f caff -d LEI16@44100 -c 1 kitchen_notification.mp3 kitchen_notification.caf
   afconvert -f caff -d LEI16@44100 -c 1 delivery_notification.mp3 delivery_notification.caf
   ```

2. **Add to Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Right-click `Runner` → "Add Files to Runner..."
   - Select your `.caf` files
   - Check "Copy items if needed"

See [ios/NOTIFICATION_SOUNDS_SETUP.md](./ios/NOTIFICATION_SOUNDS_SETUP.md) for detailed instructions.

### Step 5: Rebuild the App

```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# Build for Android
flutter build apk

# Or build for iOS
flutter build ios
```

## Code Integration

### Basic Usage

```dart
import 'package:foody_vrinda/services/notification_service.dart';
import 'package:foody_vrinda/models/user_model.dart';

final notificationService = NotificationService();

// Notify owner with custom owner sound
await notificationService.showNewOrderNotification(
  orderId: 'ORDER_123',
  customerName: 'John Doe',
  amount: 500.0,
  userRole: UserRole.owner, // 🎵 Plays owner_notification sound
);

// Notify kitchen staff with custom kitchen sound
await notificationService.showNewOrderNotification(
  orderId: 'ORDER_123',
  customerName: 'John Doe',
  amount: 500.0,
  userRole: UserRole.kitchen, // 🎵 Plays kitchen_notification sound
);

// Notify delivery staff with custom delivery sound
await notificationService.showReadyForDeliveryNotification(
  orderId: 'ORDER_123',
  customerName: 'John Doe',
  address: '123 Main St',
  userRole: UserRole.delivery, // 🎵 Plays delivery_notification sound
);
```

### Advanced Usage

See [lib/examples/notification_usage_example.dart](./lib/examples/notification_usage_example.dart) for comprehensive examples.

## How It Works

1. **Sound Configuration**: `lib/config/notification_sound_config.dart`
   - Maps user roles to sound file names
   - Generates unique notification channels per role

2. **Notification Service**: `lib/services/notification_service.dart`
   - Enhanced with `userRole` parameter
   - Automatically selects appropriate sound based on role
   - Falls back to system default if custom sound unavailable

3. **Platform-Specific**:
   - **Android**: Uses sounds from `res/raw/` directory
   - **iOS**: Uses `.caf` sounds from app bundle

## File Structure

```
foody_vrinda_app/
├── assets/
│   └── sounds/
│       ├── README.md
│       ├── owner_notification.mp3     # Place your sounds here
│       ├── kitchen_notification.mp3
│       └── delivery_notification.mp3
├── android/
│   ├── app/src/main/res/raw/
│   │   ├── owner_notification.mp3     # Android sounds
│   │   ├── kitchen_notification.mp3
│   │   └── delivery_notification.mp3
│   └── NOTIFICATION_SOUNDS_SETUP.md
├── ios/
│   ├── Runner/
│   │   ├── owner_notification.caf     # iOS sounds
│   │   ├── kitchen_notification.caf
│   │   └── delivery_notification.caf
│   └── NOTIFICATION_SOUNDS_SETUP.md
├── lib/
│   ├── config/
│   │   └── notification_sound_config.dart
│   ├── services/
│   │   └── notification_service.dart
│   └── examples/
│       └── notification_usage_example.dart
└── setup_notification_sounds.sh
```

## Testing

1. **Build and Install** the app on test devices
2. **Login** with different role accounts:
   - Owner account
   - Kitchen staff account
   - Delivery staff account
3. **Trigger notifications** for each role
4. **Verify** that:
   - Each role hears their custom sound
   - Sounds play correctly on both Android and iOS
   - Default sound plays when custom sound is unavailable

## Troubleshooting

### Sound Not Playing

**Android:**
- Verify files are in `android/app/src/main/res/raw/`
- File names must be lowercase with underscores only
- Rebuild the app after adding sounds
- Check if notification permissions are granted

**iOS:**
- Ensure device is not in silent mode
- Verify `.caf` files are added to Xcode project
- Check "Copy Bundle Resources" in Build Phases
- Rebuild the app in Xcode

### Sound File Issues

**File Format:**
- Android: Supports MP3, OGG, WAV
- iOS: Prefers CAF, also supports WAV, MP3

**File Naming:**
- Use exact names: `owner_notification`, `kitchen_notification`, `delivery_notification`
- No spaces, use underscores
- Lowercase recommended
- Extension: `.mp3` for Android, `.caf` for iOS

### Still Having Issues?

1. Check logs for notification service messages
2. Verify user role is correctly passed to notification methods
3. Ensure notification permissions are granted
4. Test with system default sound first
5. Check device notification settings

## Where to Find Free Notification Sounds

- [Freesound.org](https://freesound.org)
- [Zapsplat.com](https://www.zapsplat.com)
- [Notification Sounds](https://notificationsounds.com)
- [Mixkit.co](https://mixkit.co/free-sound-effects/)

**Tips for Selecting Sounds:**
- Choose distinct sounds for each role
- Keep sounds pleasant and not irritating
- Test sounds at different volumes
- Consider cultural appropriateness
- Avoid copyright-protected sounds

## Migration from Old Code

If you have existing notification calls, add the `userRole` parameter:

**Before:**
```dart
await notificationService.showNewOrderNotification(
  orderId: order.id,
  customerName: order.customerName,
  amount: order.total,
);
```

**After:**
```dart
await notificationService.showNewOrderNotification(
  orderId: order.id,
  customerName: order.customerName,
  amount: order.total,
  userRole: currentUser.role, // Add this parameter
);
```

## Support

For questions or issues:
1. Check the platform-specific guides in `android/` and `ios/` directories
2. Review the example code in `lib/examples/notification_usage_example.dart`
3. Consult the [Flutter Local Notifications documentation](https://pub.dev/packages/flutter_local_notifications)

---

**Happy Coding! 🎉**
