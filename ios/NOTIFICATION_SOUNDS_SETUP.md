# Adding Custom Notification Sounds for iOS

For iOS devices, notification sound files must be in CAF format and included in the app bundle.

## Instructions

### 1. Convert MP3 to CAF Format

iOS prefers `.caf` (Core Audio Format) files for notifications. Use this command on macOS to convert:

```bash
# Convert MP3 to CAF
afconvert -f caff -d LEI16@44100 -c 1 owner_notification.mp3 owner_notification.caf
afconvert -f caff -d LEI16@44100 -c 1 kitchen_notification.mp3 kitchen_notification.caf
afconvert -f caff -d LEI16@44100 -c 1 delivery_notification.mp3 delivery_notification.caf
```

**Parameters explained:**
- `-f caff`: Output format (Core Audio Format)
- `-d LEI16@44100`: 16-bit linear PCM at 44.1kHz
- `-c 1`: Mono channel (recommended for notifications)

### 2. Add Sound Files to Xcode

1. Open your project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode, right-click on `Runner` folder → "Add Files to Runner..."

3. Select your `.caf` files:
   - `owner_notification.caf`
   - `kitchen_notification.caf`
   - `delivery_notification.caf`

4. Make sure to:
   - ✅ Check "Copy items if needed"
   - ✅ Select "Create groups"
   - ✅ Add to target: Runner

### 3. Verify Files in Bundle

1. In Xcode, click on `Runner` (project root)
2. Select `Runner` target
3. Go to "Build Phases" tab
4. Expand "Copy Bundle Resources"
5. Verify your `.caf` files are listed

If not listed, drag them from the file navigator into this section.

### 4. Sound File Requirements

- **Format**: CAF (Apple Core Audio Format)
- **Duration**: 1-30 seconds (iOS allows up to 30 seconds)
- **Sample Rate**: 44.1kHz recommended
- **Channels**: Mono (1 channel) recommended
- **Bit Depth**: 16-bit Linear PCM

### 5. Alternative: Use Assets Catalog (Optional)

You can also add sounds to an asset catalog:

1. In Xcode, select `Assets.xcassets`
2. Click `+` → "New Sound Set"
3. Name it according to your sound (e.g., `owner_notification`)
4. Drag your `.caf` file into the sound set

## Testing on iOS

1. Build and run on iOS device or simulator:
   ```bash
   flutter run -d <device_id>
   ```

2. Trigger notifications for different roles
3. Verify custom sounds play correctly

## Troubleshooting

### Sound Not Playing
- Ensure device is not in silent mode (check physical switch)
- Verify sound files are in the bundle (check Xcode's Copy Bundle Resources)
- Check file names match exactly in code and bundle
- Ensure notification permissions are granted

### Converting Sound Files
If `afconvert` is not available, you can use:
- **Online converters**: CloudConvert, Online-Convert
- **Other tools**: Audacity (export as WAV, then use afconvert)
- **FFmpeg**: 
  ```bash
  ffmpeg -i input.mp3 -acodec pcm_s16le -ac 1 -ar 44100 output.caf
  ```

## Directory Structure

```
ios/
└── Runner/
    ├── Assets.xcassets/
    ├── owner_notification.caf
    ├── kitchen_notification.caf
    ├── delivery_notification.caf
    └── Info.plist
```

## Notes

- iOS respects device silent mode and Do Not Disturb settings
- For production, test on actual iOS devices (simulator behavior may differ)
- Sound duration over 30 seconds will be truncated
- If custom sound is not found, iOS uses default notification sound
