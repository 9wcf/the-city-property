import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/services/app_prefs.dart';
import 'core/services/push_service.dart';
import 'core/utils/app_utils.dart';

Future<void> bootstrap({bool prod = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  await Env.load(prod: prod);
  await initFormatters();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  await PushService.initialize();

  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) {
    await PushService.syncToken();
  }
  auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.signedOut) {
      PushService.unregister();
    } else if (state.session != null) {
      PushService.syncToken();
    }
  });

  runApp(const ProviderScope(child: TheCityPropertyApp()));
}
