#!/bin/bash

# Script to copy notification sound files from assets to Android raw directory
# Run this script from the project root

echo "🔔 Setting up custom notification sounds for Android..."

# Define paths
ASSETS_DIR="assets/sounds"
ANDROID_RAW_DIR="android/app/src/main/res/raw"

# Create raw directory if it doesn't exist
if [ ! -d "$ANDROID_RAW_DIR" ]; then
    echo "📁 Creating Android raw resources directory..."
    mkdir -p "$ANDROID_RAW_DIR"
fi

# List of sound files to copy
SOUND_FILES=(
    "owner_notification.mp3"
    "kitchen_notification.mp3"
    "delivery_notification.mp3"
)

# Counter for copied files
COPIED=0

# Copy sound files if they exist
for file in "${SOUND_FILES[@]}"; do
    if [ -f "$ASSETS_DIR/$file" ]; then
        echo "✅ Copying $file..."
        cp "$ASSETS_DIR/$file" "$ANDROID_RAW_DIR/$file"
        COPIED=$((COPIED + 1))
    else
        echo "⚠️  $file not found in $ASSETS_DIR (will use system default)"
    fi
done

echo ""
echo "📊 Summary:"
echo "   - Total files copied: $COPIED / ${#SOUND_FILES[@]}"
echo "   - Destination: $ANDROID_RAW_DIR"
echo ""

if [ $COPIED -gt 0 ]; then
    echo "✨ Setup complete! Custom notification sounds are ready."
    echo "   Next steps:"
    echo "   1. Run: flutter clean"
    echo "   2. Run: flutter pub get"
    echo "   3. Rebuild your app"
else
    echo "ℹ️  No custom sound files were copied."
    echo "   To add custom sounds:"
    echo "   1. Place MP3 files in: $ASSETS_DIR/"
    echo "   2. Use these names: ${SOUND_FILES[*]}"
    echo "   3. Run this script again"
fi

echo ""
