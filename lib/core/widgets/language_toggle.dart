import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../i18n/i18n.dart';
import 'app_text.dart';

class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    final isArabic = language == AppLanguage.ar;
    final theme = Theme.of(context);

    if (compact) {
      return IconButton(
        tooltip: isArabic ? 'English' : 'العربية',
        icon: const Icon(Icons.language_rounded),
        onPressed: () => ref
            .read(appLanguageProvider.notifier)
            .setLanguage(isArabic ? AppLanguage.en : AppLanguage.ar),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => ref
          .read(appLanguageProvider.notifier)
          .setLanguage(isArabic ? AppLanguage.en : AppLanguage.ar),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 18),
            const SizedBox(width: 6),
            Text(isArabic ? 'English' : 'العربية',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
