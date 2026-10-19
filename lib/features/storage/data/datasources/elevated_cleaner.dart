import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ElevatedCleanResult {
  final int freedBytes;
  final int removedCount;
  final int skippedCount;

  const ElevatedCleanResult({
    required this.freedBytes,
    required this.removedCount,
    required this.skippedCount,
  });
}

/// Empties a folder with admin rights via a single UAC prompt; the app itself stays unelevated.
class ElevatedCleaner {
  /// PowerShell literal: single quotes are the only thing that needs escaping.
  static String psQuote(String s) => "'${s.replaceAll("'", "''")}'";

  /// Walks by hand instead of `Get-ChildItem -Recurse`, which in Windows PowerShell 5.1
  /// follows junctions and could wander outside [root]. Reparse points are unlinked, never entered.
  static String buildScript({
    required String root,
    required DateTime olderThan,
    required String outFile,
  }) {
    final cutoffTicks =
        olderThan.toUtc().microsecondsSinceEpoch * 10 +
        621355968000000000; // .NET ticks since 0001-01-01
    return '''
\$ErrorActionPreference = 'Stop'
\$root = ${psQuote(root)}
\$out = ${psQuote(outFile)}
\$cutoff = [DateTime]::new($cutoffTicks, [DateTimeKind]::Utc)
\$freed = [long]0; \$removed = 0; \$skipped = 0
\$dirs = New-Object System.Collections.Generic.List[string]
\$stack = New-Object System.Collections.Generic.Stack[string]
\$stack.Push(\$root)
while (\$stack.Count -gt 0) {
  \$dir = \$stack.Pop()
  try { \$entries = [IO.DirectoryInfo]::new(\$dir).GetFileSystemInfos() } catch { \$skipped++; continue }
  foreach (\$e in \$entries) {
    \$isLink = (\$e.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    if (\$e -is [IO.DirectoryInfo]) {
      if (\$isLink) { try { [IO.Directory]::Delete(\$e.FullName) } catch {} }
      else { \$dirs.Add(\$e.FullName); \$stack.Push(\$e.FullName) }
    } elseif (\$e.LastWriteTimeUtc -lt \$cutoff) {
      \$len = \$e.Length
      try {
        if (\$e.IsReadOnly) { \$e.IsReadOnly = \$false }
        \$e.Delete(); \$freed += \$len; \$removed++
      } catch { \$skipped++ }
    }
  }
}
\$dirs.Sort({ param(\$a, \$b) \$b.Length.CompareTo(\$a.Length) })
foreach (\$d in \$dirs) { try { [IO.Directory]::Delete(\$d) } catch {} }
@{ freed = \$freed; removed = \$removed; skipped = \$skipped } | ConvertTo-Json | Set-Content -LiteralPath \$out -Encoding UTF8
''';
  }

  /// UTF-16LE base64, the format `powershell -EncodedCommand` expects.
  static String encode(String script) {
    final units = script.codeUnits;
    final bytes = <int>[];
    for (final u in units) {
      bytes
        ..add(u & 0xff)
        ..add(u >> 8);
    }
    return base64Encode(bytes);
  }

  /// Returns null when the user declines the UAC prompt or elevation fails.
  static Future<ElevatedCleanResult?> clean(
    String root, {
    required DateTime olderThan,
  }) async {
    if (!Platform.isWindows) return null;
    final outFile = p.join(
      Directory.systemTemp.path,
      'dustie_elevated_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    final encoded = encode(
      buildScript(root: root, olderThan: olderThan, outFile: outFile),
    );

    try {
      // The outer, unelevated shell only launches the elevated one and waits for it.
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden "
            "-ArgumentList '-NoProfile','-NonInteractive','-EncodedCommand','$encoded'",
      ]);
      final out = File(outFile);
      if (res.exitCode != 0 || !await out.exists()) return null;

      var text = await out.readAsString();
      if (text.startsWith('﻿')) text = text.substring(1);
      await out.delete();
      final json = jsonDecode(text) as Map<String, dynamic>;
      return ElevatedCleanResult(
        freedBytes: (json['freed'] as num).toInt(),
        removedCount: (json['removed'] as num).toInt(),
        skippedCount: (json['skipped'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
