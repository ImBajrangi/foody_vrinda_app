# Fixing Google Sign-In `DEVELOPER_ERROR` (Code 10)

The `DEVELOPER_ERROR` is a common but frustrating mismatch between your app's environment and the Google/Firebase configuration.

## Root Cause
Google Play Services verifies your app's identity using a pair of **Package Name** and **SHA-1 Fingerprint**. If they don't exactly match what's registered in the Firebase/Google Cloud Console, Google rejects the request.

### Common Reasons:
1. **Missing Support Email**: Google Sign-In requires a "Support Email" to be selected in Firebase Settings.
2. **Missing SHA Certificate**: You might have added the Debug SHA, but not the Release SHA, or vice-versa.
3. **Google Play App Signing**: If you uploaded to the Play Store, Google re-signs your app. You must add their "App Signing Key" SHA-1 to Firebase.
4. **Configuration Sync**: After adding a SHA, you must often wait a few minutes or re-download `google-services.json`.

---

## 🛠️ The "Fix it for Everytime" Solution

### Step 1: Collect ALL your Fingerprints
Run this in your terminal to get the SHA codes for your current machine:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```
> [!IMPORTANT]
> Copy both **SHA-1** and **SHA-256**.

### Step 2: Add to Firebase Console
1. Go to **Firebase Console** > **Project Settings (⚙️)**.
2. Scroll to **Your Apps** > **Android App**.
3. Click **Add Fingerprint** and add BOTH the SHA-1 and SHA-256 you just copied.
4. **Crucial**: Ensure the "Support Email" is set at the top of the General tab.

### Step 3: Configure the OAuth Consent Screen
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Select your Firebase project.
3. Go to **APIs & Services** > **OAuth consent screen**.
4. Ensure it's configured and that the **Support Email** is the same as in Firebase.

### Step 4: Use the correct Client ID in Code
Always initialize `GoogleSignIn` like this in your `AuthService`:
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  // Use the "Web Client ID" for serverClientId even on Android
  serverClientId: 'YOUR_CLIENT_ID_FROM_JSON_TYPE_3',
);
```

### Step 5: (If Play Store) Add Production SHA
If you have published the app, go to **Google Play Console** > **Setup** > **App Integrity** and copy the **App Signing Key Certificate SHA-1** into Firebase as well.
