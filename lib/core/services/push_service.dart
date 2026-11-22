import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تسجيل التوكن وحفظه، وعرض إشعارات النظام عندما يكون التطبيق مغلقاً.
class PushService {
  PushService._();

  static bool _ready = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!supported) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      _ready = true;
    } catch (error, stack) {
      debugPrint('PushService init failed: $error\n$stack');
    }
  }

  /// يُستدعى بعد الدخول وبعد تجديد الجلسة.
  static Future<void> syncToken() async {
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    } catch (error) {
      debugPrint('PushService token sync failed: $error');
    }
  }

  /// يُستدعى عند الخروج لحذف توكن الجهاز.
  static Future<void> unregister() async {
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client.rpc(
        'unregister_device_token',
        params: {'p_token': token},
      );
    } catch (error) {
      debugPrint('PushService unregister failed: $error');
    }
  }

  static Future<void> _saveToken(String token) async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    await Supabase.instance.client.rpc(
      'register_device_token',
      params: {'p_token': token, 'p_platform': 'android'},
    );
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
