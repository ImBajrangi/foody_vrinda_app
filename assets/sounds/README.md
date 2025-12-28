# Notification Sound Assets

This directory contains custom notification sounds for different staff roles.

## Sound Files Structure

Place your custom notification sound files in this directory with the following naming convention:

- `owner_notification.mp3` - Sound for owner notifications
- `kitchen_notification.mp3` - Sound for kitchen staff notifications
- `delivery_notification.mp3` - Sound for delivery staff notifications
- `default_notification.mp3` - Default sound for general notifications

## Supported Formats

- **Android**: MP3, OGG, WAV
- **iOS**: CAF, AIF, WAV, MP3 (CAF recommended for best compatibility)

## Creating Custom Sounds

1. Keep sound files short (1-3 seconds recommended)
2. Keep file sizes small (< 100KB recommended)
3. Use appropriate volume levels
4. Test on both Android and iOS devices

## Default Behavior

If custom sound files are not provided, the system will use the default device notification sound.

## Adding Sounds

1. Add your sound files to this directory
2. Ensure file names match exactly as specified above
3. Run `flutter pub get` to register the assets
4. Rebuild the app

## Converting to CAF for iOS (Optional)

To convert MP3 to CAF format for better iOS compatibility:

```bash
afconvert -f caff -d LEI16@44100 -c 1 input.mp3 output.caf
```

## Note

For Android, sound files will be automatically copied to the `android/app/src/main/res/raw/` directory during the build process.
