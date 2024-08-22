import 'package:cimage_attendance/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FirebaseServices {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    if (!kDebugMode) {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    await remoteConfig.setDefaults(<String, dynamic>{
      "latest_app": {"version": packageInfo.version}.toString(),
      "developer": {"name": "Vishal", "socials": [], "notes": []}.toString(),
      "bg_attendance_active": true,
      "app_active": true,
    });
    await remoteConfig.fetchAndActivate();
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {}
  }
}
