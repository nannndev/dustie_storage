import 'dart:io';

class SystemLauncher {
  static Future<bool> revealInFileManager(String path) async {
    try {
      if (Platform.isMacOS) {
        final res = await Process.run('open', ['-R', path]);
        return res.exitCode == 0;
      } else if (Platform.isWindows) {
        final res = await Process.run('explorer.exe', ['/select,', path]);
        return res.exitCode == 0;
      } else if (Platform.isLinux) {
        final parent = File(path).parent.path;
        final res = await Process.run('xdg-open', [parent]);
        return res.exitCode == 0;
      }
    } catch (_) {}
    return false;
  }
}
