import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../core/i18n/i18n.dart';
import '../core/theme/app_theme.dart';
import 'auth_gate.dart';
import 'providers.dart';

class TheCityPropertyApp extends ConsumerWidget {
  const TheCityPropertyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    final isEnglish = language == AppLanguage.en;
    I18n.setLanguage(language);
    intl.Intl.defaultLocale = language.name;

    return MaterialApp(
      key: ValueKey(language.name),
      title: isEnglish ? 'The City Property' : 'The City Property',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: Locale(language.name),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection:
              isEnglish ? TextDirection.ltr : TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}
