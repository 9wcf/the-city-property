import 'dart:io';

import '../lib/core/i18n/i18n.dart';

/// Reports Arabic string literals with `$` interpolation that still render in
/// Arabic when the app language is English. Interpolated values are replaced
/// with `X` before translating.
void main(List<String> args) {
  final roots = args.isEmpty
      ? ['lib/features', 'lib/data', 'lib/core']
      : args;
  final literal = RegExp(r"'([^'\\\n]*(?:\\.[^'\\\n]*)*)'");
  final arabic = RegExp('[\u0600-\u06FF]');
  final interpolation = RegExp(r'\$\{[^{}]*\}');
  final simple = RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*');
  final found = <String>{};

  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/i18n/')) continue;
      final source = entity.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        final raw = match.group(1)!;
        if (!arabic.hasMatch(raw) || !raw.contains(r'$')) continue;
        if (raw.startsWith('^') && raw.endsWith(r'$')) continue;
        found.add(raw);
      }
    }
  }

  I18n.setLanguage(AppLanguage.en);
  final missing = <String>[];
  for (final text in found) {
    var sample = text;
    while (interpolation.hasMatch(sample)) {
      sample = sample.replaceAll(interpolation, '7');
    }
    sample = sample.replaceAll(simple, '7');
    final translated = I18n.translate(sample);
    if (arabic.hasMatch(translated)) missing.add('$text  ==>  $translated');
  }
  missing.sort();
  for (final text in missing) {
    stdout.writeln(text);
  }
  stderr.writeln('total=${found.length} missing=${missing.length}');
}
