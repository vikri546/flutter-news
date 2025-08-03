import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';

class IntentHelper {
  /// Launch URL with Android Intent Chooser
  static Future<bool> launchUrlWithChooser(String url, {String? title}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: url,
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_ACTIVITY_CLEAR_TOP,
        ],
      );

      await intent.launchChooser(title ?? 'Open with');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Launch URL with specific browser package
  static Future<bool> launchUrlWithPackage(String url, String packageName) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: url,
        package: packageName,
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
        ],
      );

      await intent.launch();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get list of common browser packages
  static List<BrowserInfo> getCommonBrowsers() {
    return [
      BrowserInfo(
        name: 'Chrome',
        packageName: 'com.android.chrome',
        icon: 'chrome',
      ),
      BrowserInfo(
        name: 'Firefox',
        packageName: 'org.mozilla.firefox',
        icon: 'firefox',
      ),
      BrowserInfo(
        name: 'Edge',
        packageName: 'com.microsoft.emmx',
        icon: 'edge',
      ),
      BrowserInfo(
        name: 'Opera',
        packageName: 'com.opera.browser',
        icon: 'opera',
      ),
      BrowserInfo(
        name: 'Samsung Internet',
        packageName: 'com.sec.android.app.sbrowser',
        icon: 'samsung',
      ),
      BrowserInfo(
        name: 'Brave',
        packageName: 'com.brave.browser',
        icon: 'brave',
      ),
    ];
  }

  /// Check if app is installed
  static Future<bool> isAppInstalled(String packageName) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: packageName,
      );

      // Try to resolve the intent
      return await intent.canResolveActivity() ?? false;
    } catch (e) {
      return false;
    }
  }
}

class BrowserInfo {
  final String name;
  final String packageName;
  final String icon;

  BrowserInfo({
    required this.name,
    required this.packageName,
    required this.icon,
  });
}
