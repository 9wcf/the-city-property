import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';

class AppPrefs {
  AppPrefs._();

  static SharedPreferences? instance;

  static const _languageKey = 'app_language';

  static Future<void> init() async {
    instance = await SharedPreferences.getInstance();
    final saved = instance?.getString(_languageKey);
    if (saved == 'en') {
      I18n.setLanguage(AppLanguage.en);
    } else if (saved == 'ar') {
      I18n.setLanguage(AppLanguage.ar);
    }
  }

  static Future<void> saveLanguage(AppLanguage language) async {
    await instance?.setString(_languageKey, language.name);
  }
}
