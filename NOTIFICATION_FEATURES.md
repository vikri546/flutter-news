# Notification Features Documentation

## Overview

This document describes the comprehensive notification system implemented in the d'talk news application.

## Features

### 1. Notification Types

- **Breaking News**: High-priority notifications for important news
- **Trending Articles**: Notifications for popular and trending content
- **Recommendations**: Personalized article recommendations

### 2. Volume and Sound Improvements

- **Maximum Volume Configuration**: All notification channels now use maximum importance levels
- **Enhanced Vibration Patterns**: Longer and more noticeable vibration sequences
- **LED Light Indicators**: Color-coded LED notifications for different types
- **Audio Permissions**: Added MODIFY_AUDIO_SETTINGS and ACCESS_NOTIFICATION_POLICY permissions

#### Volume Levels by Type:

- **Breaking News**: `Importance.max` + `Priority.max` + Extended vibration pattern
- **Trending Articles**: `Importance.high` + `Priority.high` + Medium vibration pattern
- **Recommendations**: `Importance.defaultImportance` + `Priority.defaultPriority` + Standard vibration

#### Vibration Patterns:

- **Breaking News**: `[0, 1000, 500, 1000, 500, 1000]` (3 long vibrations)
- **Trending**: `[0, 800, 400, 800]` (2 medium vibrations)
- **Recommendations**: `[0, 500, 200, 500]` (2 short vibrations)

### 3. Testing Features

- **Test Notification Button**: Standard notification test
- **Maximum Volume Test Button**: Test with enhanced volume settings
- **Volume Reset Function**: Automatically recreates channels with maximum settings

### 4. Background Processing

- **WorkManager Integration**: Handles background notification tasks
- **Periodic Notifications**: Sends notifications every 4 hours
- **Smart Scheduling**: Avoids notification spam with time-based limits

### 5. Permission Management

- **Android 13+ Support**: Proper POST_NOTIFICATIONS permission handling
- **Location Integration**: Combines with location services for relevant content
- **Audio Control**: Permissions for maximum volume control

### 6. User Experience

- **Localized Content**: Notifications in user's preferred language
- **Rich Notifications**: Large icons, colors, and expanded text
- **Auto-cleanup**: Removes old notifications automatically
- **Badge Support**: Shows notification count on app icon

## Technical Implementation

### Notification Channels

```dart
// Breaking News - Maximum Volume
AndroidNotificationChannel(
  'breaking_news',
  'Breaking News',
  importance: Importance.max,
  priority: Priority.max,
  playSound: true,
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
  showBadge: true,
  enableLights: true,
  ledColor: Color(0xFFE74C3C),
)
```

### Volume Enhancement Methods

```dart
// Ensure maximum volume for all notifications
await NotificationService().ensureMaximumVolume();

// Test with maximum volume settings
await NotificationService().testMaximumVolumeNotification();
```

### Android Manifest Permissions

```xml
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
```

## Usage Instructions

### For Users:

1. **Enable Notifications**: Grant permission when prompted
2. **Test Volume**: Use "Test Maximum Volume" button in notifications screen
3. **Adjust Device Settings**: Ensure device volume is not muted
4. **Check Do Not Disturb**: Disable DND mode for full notification experience

### For Developers:

1. **Test Notifications**: Use the test buttons in NotificationsScreen
2. **Monitor Logs**: Check console for notification delivery status
3. **Volume Issues**: Use `ensureMaximumVolume()` method to reset channels
4. **Customization**: Modify vibration patterns and importance levels as needed

## Troubleshooting

### Common Issues:

1. **Low Volume**:
   - Check device volume settings
   - Use "Test Maximum Volume" button
   - Ensure DND mode is disabled
2. **No Sound**:

   - Verify notification permissions
   - Check if sound file exists in `android/app/src/main/res/raw/`
   - Restart app after permission changes

3. **No Vibration**:
   - Check device vibration settings
   - Verify VIBRATE permission is granted
   - Test with different notification types

### Debug Commands:

```bash
# Check notification channels
adb shell dumpsys notification | grep -A 10 "dtalk"

# Test notification manually
adb shell am broadcast -a com.android.systemui.action.NOTIFICATION_TEST
```

## Future Enhancements

- **Custom Sound Files**: Allow users to choose notification sounds
- **Volume Slider**: In-app volume control for notifications
- **Schedule Preferences**: User-defined notification timing
- **Smart Filtering**: AI-powered notification relevance scoring
