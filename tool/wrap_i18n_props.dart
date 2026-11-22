import 'dart:io';

/// Wraps Arabic literals passed to framework text properties (hints, labels,
/// tooltips) in `tr(...)` so they follow the app language.
void main() {
  final arabic = RegExp('[\u0600-\u06FF]');
  final prop = RegExp(
    r'(labelText|hintText|helperText|tooltip):\s*'
    r"('(?:[^'\\\n]|\\.)*')",
  );
  var changedFiles = 0;
  var changedValues = 0;

  for (final root in ['lib/features', 'lib/core']) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.replaceAll(r'\', '/').contains('/i18n/')) continue;
      var source = entity.readAsStringSync();
      var changed = false;
      source = source.replaceAllMapped(prop, (match) {
        final value = match.group(2)!;
        if (!arabic.hasMatch(value)) return match.group(0)!;
        final before = match.start == 0
            ? ''
            : source.substring(match.start - 3, match.start);
        if (before == 'tr(') return match.group(0)!;
        changed = true;
        changedValues++;
        return '${match.group(1)}: tr($value)';
      });
      if (changed) {
        entity.writeAsStringSync(source);
        changedFiles++;
        stdout.writeln(entity.path);
      }
    }
  }
  stderr.writeln('files=$changedFiles values=$changedValues');
}
