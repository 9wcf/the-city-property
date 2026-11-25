import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_city_property/core/i18n/i18n.dart';
import 'package:the_city_property/core/theme/app_theme.dart';
import 'package:the_city_property/data/models.dart';
import 'package:the_city_property/features/shared/profile_screen.dart';

void main() {
  testWidgets('profile exposes account deletion and privacy policy',
      (tester) async {
    I18n.setLanguage(AppLanguage.ar);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const profile = AppProfile(
      id: 'tenant-1',
      fullName: 'مستأجر تجريبي',
      phoneNumber: '07701112223',
      role: UserRole.tenant,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: ProfileScreen(profile: profile)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ListView);
    await tester.dragUntilVisible(
      find.text('حذف الحساب'),
      list,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('سياسة الخصوصية'), findsOneWidget);
    expect(find.text('حذف الحساب'), findsOneWidget);

    await tester.tap(find.text('حذف الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('حذف الحساب نهائياً؟'), findsOneWidget);
    expect(find.text('حذف نهائي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
