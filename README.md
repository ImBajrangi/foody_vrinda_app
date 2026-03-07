# Foody Vrinda - Cloud Kitchen Mobile App

A Flutter-based mobile application for the Foody Vrinda cloud kitchen ordering system. This app provides a seamless food ordering experience with real-time order tracking and multi-role support.

## Features

### Customer Features
- 🏪 Browse available shops
- 📋 View menu items with images and prices
- 🛒 Add items to cart with quantity controls
- 📱 Place orders with delivery details
- 📍 Real-time order tracking
- 🔔 Push notifications for order updates

### Staff Features
- 👨‍🍳 **Kitchen View**: Manage incoming orders, mark as preparing/ready
- 🛵 **Delivery View**: Handle delivery orders
- 📊 **Owner Dashboard**: View revenue, order statistics, and manage staff
- 🛠️ **Developer Panel**: System testing and debugging tools

## Tech Stack

- **Flutter** - Cross-platform mobile development
- **Firebase Auth** - User authentication
- **Cloud Firestore** - Real-time database
- **Provider** - State management
- **Google Fonts** - Typography

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Android Studio / Xcode (for emulators)
- Firebase project configured

### Installation

1. Clone the repository
2. Navigate to the app directory:
   ```bash
   cd foody_vrinda_app
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

### Build Commands

**Android APK (Debug):**
```bash
flutter build apk --debug
```

**Android APK (Release):**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle
```

**iOS (Debug):**
```bash
flutter build ios --debug
```

**Web:**
```bash
flutter build web
```

## Project Structure

```
lib/
├── config/              # App configuration
│   ├── firebase_config.dart
│   └── theme.dart
├── models/              # Data models
│   ├── cart_item_model.dart
│   ├── menu_item_model.dart
│   ├── notification_model.dart
│   ├── order_model.dart
│   ├── shop_model.dart
│   └── user_model.dart
├── providers/           # State management
│   ├── auth_provider.dart
│   └── cart_provider.dart
├── screens/             # UI screens
│   ├── auth/
│   ├── cart/
│   ├── home/
│   ├── menu/
│   └── order/
├── services/            # Business logic
│   ├── auth_service.dart
│   ├── order_service.dart
│   └── shop_service.dart
├── widgets/             # Reusable components
│   ├── buttons.dart
│   ├── cards.dart
│   ├── inputs.dart
│   └── order_widgets.dart
└── main.dart            # App entry point
```

## User Roles

| Role | Access |
|------|--------|
| **Customer** | Order food, track orders |
| **Kitchen** | Manage orders, update status |
| **Delivery** | Handle deliveries |
| **Owner** | Dashboard, staff management |
| **Developer** | Full system access |

## Firebase Configuration

The app connects to the Foody Vrinda Firebase project. Configuration is handled in `main.dart` with the Firebase options.

## Related Projects

- **Web Version**: `kitchen.html` in the parent directory
- **Original APK**: Located in `official_app/` folder

## License

© Vrindopnishad. All rights reserved.

## for emulator

flutter emulators --launch Medium_Phone_API_36.1

flutter clean && flutter pub get && flutter build apk --release

flutter build apk --release

