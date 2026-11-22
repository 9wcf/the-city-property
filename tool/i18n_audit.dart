import 'dart:io';

import '../lib/core/i18n/i18n.dart';

/// Scans Arabic UI literals in the given folders and reports the ones that
/// would still render in Arabic when the app language is English.
void main(List<String> args) {
  final roots = args.isEmpty
      ? ['lib/features/owner', 'lib/features/shared', 'lib/core']
      : args;
  final literal = RegExp(r"'([^'\\\n]*(?:\\.[^'\\\n]*)*)'");
  final arabic = RegExp('[\u0600-\u06FF]');
  final found = <String>{};

  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        final raw = match.group(1)!;
        if (!arabic.hasMatch(raw)) continue;
        if (raw.contains(r'$')) continue; // handled separately by patterns
        found.add(raw);
      }
    }
  }

  I18n.setLanguage(AppLanguage.en);
  final missing = <String>[];
  for (final text in found) {
    final translated = I18n.translate(text);
    if (arabic.hasMatch(translated)) missing.add(text);
  }
  missing.sort();
  for (final text in missing) {
    stdout.writeln(text);
  }
  stderr.writeln('total=${found.length} missing=${missing.length}');
}
