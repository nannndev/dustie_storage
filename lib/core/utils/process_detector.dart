import 'dart:io';

class ProcessDetector {
  /// Lowercased executable names of everything running, e.g. {"chrome.exe", "explorer.exe"}.
  /// Empty on failure: a missing warning is better than a crash.
  static Future<Set<String>> runningProcessNames() async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        if (res.exitCode != 0) return {};
        return parseTasklistCsv(res.stdout as String);
      }
      final res = await Process.run('ps', ['-A', '-o', 'comm=']);
      if (res.exitCode != 0) return {};
      return {
        for (final line in (res.stdout as String).split('\n'))
          if (line.trim().isNotEmpty) line.trim().split('/').last.toLowerCase(),
      };
    } catch (_) {
      return {};
    }
  }

  /// `"chrome.exe","1234","Console","1","120,000 K"` → chrome.exe
  static Set<String> parseTasklistCsv(String csv) => {
    for (final line in csv.split('\n'))
      if (line.startsWith('"'))
        line.substring(1, line.indexOf('"', 1)).toLowerCase(),
  };
}
