# Splash Screen Configuration

## Changes Made

### 1. **Android 12+ (API 31+) - Modern Splash Screen**
- **File**: `values-v31/styles.xml` and `values-night-v31/styles.xml`
- **Features**:
  - ✅ **No rounding**: Set `windowSplashScreenIconBackgroundColor` to transparent
  - ✅ **Animation**: Built-in Android 12+ splash screen animation (fade + scale)
  - ✅ **Perfect display**: Icon displayed without compression
  - ✅ **Animation duration**: 1000ms (1 second)

### 2. **Older Android Versions (Pre-API 31)**
- **Files**: `drawable/launch_background.xml` and `drawable-v21/launch_background.xml`
- **Features**:
  - ✅ **No compression**: Added `antialias="true"` and `filter="true"`
  - ✅ **Proper centering**: Logo centered without distortion
  - ✅ **Tile mode disabled**: Prevents image tiling

### 3. **Icon Drawable**
- **File**: `drawable/splash_icon_no_round.xml`
- **Purpose**: Wrapper to prevent rounding on Android 12+ splash icons
- **Usage**: Referenced in Android 12+ styles

## How It Works

### Android 12+ (API 31+)
- Uses native Android 12+ Splash Screen API
- Icon animates automatically (fade in + scale up)
- No rounding due to transparent background
- Perfect image display without compression

### Older Versions
- Uses traditional launch_background.xml
- Logo displayed with proper anti-aliasing
- No compression or distortion

## Image Requirements

### For `android12splash.png` (Android 12+):
- Recommended size: 288x288dp (or larger)
- Should be square or properly sized
- PNG format with transparency
- No rounded corners in the image itself

### For `splash.png` (Older versions):
- Recommended size: Match your logo dimensions
- PNG format
- Centered in the image

## Testing

1. **Test on Android 12+ device/emulator**:
   - Should see animated splash screen
   - Logo should appear without rounding
   - Animation should be smooth

2. **Test on older Android versions**:
   - Should see static splash screen
   - Logo should be centered and clear
   - No compression or distortion

## Customization

### Change Animation Duration
Edit `values-v31/styles.xml`:
```xml
<item name="android:windowSplashScreenAnimationDuration">1500</item>
```
(Value in milliseconds)

### Change Background Color
Edit `values-v31/styles.xml`:
```xml
<item name="android:windowSplashScreenBackground">#YOUR_COLOR</item>
```

### Disable Branding Image
Remove or comment out:
```xml
<item name="android:windowSplashScreenBrandingImage">@drawable/splash</item>
```

## Notes

- The splash screen animation is built-in for Android 12+
- For older versions, animation would need to be handled in Flutter code
- Ensure your splash images are high quality and properly sized
- Test on multiple Android versions for best results

