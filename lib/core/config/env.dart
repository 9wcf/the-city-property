import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static Future<void> load({bool prod = false}) async {
    await dotenv.load(fileName: prod ? 'env.prod' : 'env.dev');
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'dev';
  static String get currency => dotenv.env['CURRENCY'] ?? 'IQD';
  static String get appName => dotenv.env['APP_NAME'] ?? 'The City Property';

  static bool get isProd => appEnv == 'prod';
}
