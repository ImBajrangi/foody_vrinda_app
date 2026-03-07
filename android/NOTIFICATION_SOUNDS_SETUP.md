# Adding Custom Notification Sounds for Android

For Android devices, notification sound files must be placed in the `res/raw` directory.

## Instructions

1. **Navigate to the Android raw resources directory:**
   ```
   android/app/src/main/res/raw/
   ```
   If the `raw` directory doesn't exist, create it.

2. **Add your sound files** with these exact names:
   - `owner_notification.mp3` - Sound for owner notifications
   - `kitchen_notification.mp3` - Sound for kitchen staff notifications
   - `delivery_notification.mp3` - Sound for delivery staff notifications

3. **Sound file requirements:**
   - Format: MP3, OGG, or WAV
   - Duration: 1-3 seconds recommended
   - File size: < 100KB recommended
   - Sample rate: 44.1kHz recommended
   - Naming: Use lowercase with underscores only (no spaces, no special characters)

4. **After adding sounds:**
   ```bash
   cd android
   ./gradlew clean
   cd ..
   flutter clean
   flutter pub get
   flutter build apk
   ```

## Directory Structure

```
android/
└── app/
    └── src/
        └── main/
            └── res/
                └── raw/
                    ├── owner_notification.mp3
                    ├── kitchen_notification.mp3
                    └── delivery_notification.mp3
```

## Testing

After building and installing the app:
1. Log in with different role accounts (owner, kitchen, delivery)
2. Trigger notifications for each role
3. Verify that different sounds play for each role

## Notes

- Sound files are automatically included in the APK during build
- If a custom sound file is missing, the system default notification sound will be used
- Make sure file names match exactly (case-sensitive on some systems)
