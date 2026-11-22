import 'dart:io';

/// Adds missing i18n imports and removes `const` from constructors whose
/// arguments now call `tr(...)`.
void main() {
  _addImports();
  for (var i = 0; i < 12; i++) {
    final output = Process.runSync(
      'C:/src/flutter/bin/flutter.bat',
      ['analyze', '--no-pub'],
    ).stdout.toString();
    final errors = <(String, int, int)>[];
    for (final line in output.split('\n')) {
      if (!line.contains('const_eval_method_invocation') &&
          !line.contains('invalid_constant')) {
        continue;
      }
      final parts = line.split(' - ');
      if (parts.length < 3) continue;
      final match = RegExp(r'^(.+\.dart):(\d+):(\d+)$').firstMatch(parts[2]);
      if (match == null) continue;
      errors.add((
        match.group(1)!.replaceAll(r'\', '/'),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      ));
    }
    if (errors.isEmpty) {
      stderr.writeln('const errors cleared after $i passes');
      return;
    }
    stderr.writeln('pass $i: ${errors.length} const errors');
    stderr.writeln('first: ${errors.first}');
    final byFile = <String, List<(int, int)>>{};
    for (final (path, line, col) in errors) {
      byFile.putIfAbsent(path, () => []).add((line, col));
    }
    for (final entry in byFile.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      final offsets = <int>[];
      var offset = 0;
      for (final line in lines) {
        offsets.add(offset);
        offset += line.length + 1;
      }
      final positions = <int>[];
      for (final (line, col) in entry.value) {
        if (line < 1 || line > lines.length) continue;
        positions.add(offsets[line - 1] + col - 1);
      }
      positions.sort((a, b) => b.compareTo(a));
      var out = source;
      for (final pos in positions) {
        final prefix = out.substring(0, pos.clamp(0, out.length));
        final constMatch = RegExp(r'\bconst\b\s*').allMatches(prefix).lastOrNull;
        if (constMatch == null) continue;
        out = out.replaceRange(constMatch.start, constMatch.end, '');
      }
      file.writeAsStringSync(out);
      stderr.writeln('  fixed ${entry.key}');
    }
  }
}

void _addImports() {
  for (final root in ['lib/features']) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      var source = entity.readAsStringSync();
      if (!source.contains('tr(') ||
          source.contains('core/i18n/i18n.dart')) {
        continue;
      }
      final normalized = entity.path.replaceAll(r'\', '/');
      final segments = normalized.split('/');
      final libIndex = segments.indexOf('lib');
      final depth = segments.length - libIndex - 2;
      final import =
          "import '${'../' * depth}core/i18n/i18n.dart';\n";
      final lines = source.split('\n');
      var lastImport = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('import ')) lastImport = i;
      }
      if (lastImport == -1) continue;
      lines.insert(lastImport + 1, import.trimRight());
      source = lines.join('\n');
      entity.writeAsStringSync(source);
      stderr.writeln('imported ${entity.path}');
    }
  }
}
