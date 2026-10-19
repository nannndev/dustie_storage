import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../domain/entities/delete_result.dart';
import '../../domain/entities/junk_location.dart';
import '../../../../core/utils/process_detector.dart';
import 'best_effort_delete.dart';
import 'elevated_cleaner.dart';

abstract class JunkLocationDataSource {
  /// Known junk folders for this OS that exist on disk right now.
  Future<List<JunkLocation>> findLocations();

  Future<JunkMeasurement> measure(JunkLocation location);

  Future<DeleteResult> clean(JunkLocation location);

  /// Retries [location] with admin rights (one UAC prompt). Null if declined or unsupported.
  Future<ElevatedCleanResult?> cleanElevated(JunkLocation location);

  Future<Set<String>> runningProcesses();
}

typedef _Spec = (String?, String, String, JunkKind, JunkRisk);

/// Extra per-location metadata keyed by display name, kept out of the spec tuples.
typedef _Extras = ({List<String> owners, bool elevate});

class JunkLocationDataSourceImpl implements JunkLocationDataSource {
  /// Temp files younger than this may belong to a running app (Linux/macOS don't lock open files).
  static const tempMinAge = Duration(hours: 24);

  final Map<String, String> _env;

  JunkLocationDataSourceImpl({Map<String, String>? environment})
    : _env = environment ?? Platform.environment;

  static DateTime? _cutoffFor(JunkLocation l) =>
      l.kind == JunkKind.temp ? DateTime.now().subtract(tempMinAge) : null;

  @override
  Future<List<JunkLocation>> findLocations() async {
    final candidates = Platform.isWindows
        ? _windows()
        : Platform.isMacOS
        ? _macos()
        : Platform.isLinux
        ? _linux()
        : const <JunkLocation>[];

    final seen = <String>{};
    final found = <JunkLocation>[];
    for (final c in candidates) {
      final key = p.normalize(c.path).toLowerCase();
      if (!isSafeTarget(c.path) || !seen.add(key)) continue;
      if (await Directory(c.path).exists()) found.add(c);
    }
    return found;
  }

  /// Guards against an env var pointing somewhere catastrophic (drive root, home, system folders).
  bool isSafeTarget(String path) {
    final norm = p.normalize(path);
    if (norm == p.rootPrefix(norm) || p.split(norm).length < 3) return false;
    for (final key in ['USERPROFILE', 'HOME', 'WINDIR', 'SystemRoot']) {
      final v = _env[key];
      if (v != null && v.isNotEmpty && p.equals(norm, v)) return false;
    }
    return true;
  }

  @override
  Future<JunkMeasurement> measure(JunkLocation location) {
    final path = location.path;
    final cutoff = _cutoffFor(location);
    return Isolate.run(() {
      var bytes = 0;
      var count = 0;
      try {
        for (final e in Directory(
          path,
        ).listSync(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          try {
            final stat = e.statSync();
            if (cutoff != null && !stat.modified.isBefore(cutoff)) continue;
            bytes += stat.size;
            count++;
          } catch (_) {}
        }
      } on FileSystemException {
        // Partial listing (permission on a subfolder) still gives a useful estimate.
      }
      return JunkMeasurement(bytes: bytes, fileCount: count);
    });
  }

  @override
  Future<DeleteResult> clean(JunkLocation location) {
    final path = location.path;
    final cutoff = _cutoffFor(location);
    if (!isSafeTarget(path)) return Future.value(const DeleteResult());
    return Isolate.run(
      () => BestEffortDelete.tree(path, keepRoot: true, olderThan: cutoff),
    );
  }

  @override
  Future<ElevatedCleanResult?> cleanElevated(JunkLocation location) {
    if (!location.canElevate || !isSafeTarget(location.path)) {
      return Future.value(null);
    }
    return ElevatedCleaner.clean(
      location.path,
      olderThan: _cutoffFor(location) ?? DateTime.now(),
    );
  }

  @override
  Future<Set<String>> runningProcesses() =>
      ProcessDetector.runningProcessNames();

  String? _join(String? base, List<String> parts) =>
      base == null || base.isEmpty ? null : p.joinAll([base, ...parts]);

  List<JunkLocation> _build(
    List<_Spec> specs, [
    Map<String, _Extras> extras = const {},
  ]) => [
    for (final (path, name, desc, kind, risk) in specs)
      if (path != null && path.isNotEmpty)
        JunkLocation(
          id: '${kind.name}:$name',
          name: name,
          description: desc,
          path: path,
          kind: kind,
          risk: risk,
          ownerProcesses: extras[name]?.owners ?? const [],
          canElevate: extras[name]?.elevate ?? false,
        ),
  ];

  List<JunkLocation> _windows() {
    final local = _env['LOCALAPPDATA'];
    final home = _env['USERPROFILE'];
    return _build(
      [
        (
          _env['TEMP'] ?? _join(local, ['Temp']),
          'User Temp',
          'Leftovers from installers and apps (older than 1 day)',
          JunkKind.temp,
          JunkRisk.safe,
        ),
        (
          _join(_env['WINDIR'], ['Temp']),
          'Windows Temp',
          'System temp files; some need admin rights',
          JunkKind.temp,
          JunkRisk.safe,
        ),
        (
          _join(local, ['CrashDumps']),
          'Crash Dumps',
          'Memory dumps from crashed apps',
          JunkKind.crashDumps,
          JunkRisk.safe,
        ),
        (
          _join(local, ['Microsoft', 'Windows', 'WER']),
          'Error Reports',
          'Windows Error Reporting archives',
          JunkKind.crashDumps,
          JunkRisk.safe,
        ),
        (
          _join(local, ['Google', 'Chrome', 'User Data', 'Default', 'Cache']),
          'Chrome Cache',
          'Cached web pages; close Chrome to clear it fully',
          JunkKind.browserCache,
          JunkRisk.regenerable,
        ),
        (
          _join(local, ['Microsoft', 'Edge', 'User Data', 'Default', 'Cache']),
          'Edge Cache',
          'Cached web pages; close Edge to clear it fully',
          JunkKind.browserCache,
          JunkRisk.regenerable,
        ),
        (
          _join(local, ['npm-cache']),
          'npm Cache',
          'Downloaded packages; re-fetched on next install',
          JunkKind.devCache,
          JunkRisk.regenerable,
        ),
        (
          _join(home, ['.gradle', 'caches']),
          'Gradle Caches',
          'Build dependencies; next Android build re-downloads them',
          JunkKind.devCache,
          JunkRisk.regenerable,
        ),
      ],
      {
        'Windows Temp': (owners: const [], elevate: true),
        'Chrome Cache': (owners: const ['chrome.exe'], elevate: false),
        'Edge Cache': (owners: const ['msedge.exe'], elevate: false),
        'Gradle Caches': (owners: const ['java.exe'], elevate: false),
      },
    );
  }

  List<JunkLocation> _macos() {
    final home = _env['HOME'];
    return _build(
      [
        (
          _env['TMPDIR'],
          'User Temp',
          'Per-user temp files (older than 1 day)',
          JunkKind.temp,
          JunkRisk.safe,
        ),
        (
          _join(home, ['Library', 'Caches']),
          'App Caches',
          'Caches apps rebuild on demand',
          JunkKind.appCache,
          JunkRisk.regenerable,
        ),
        (
          _join(home, ['Library', 'Logs']),
          'Logs',
          'Application and diagnostic logs',
          JunkKind.logs,
          JunkRisk.safe,
        ),
        (
          _join(home, ['Library', 'Developer', 'Xcode', 'DerivedData']),
          'Xcode DerivedData',
          'Build intermediates; next build is slower',
          JunkKind.devCache,
          JunkRisk.regenerable,
        ),
        (
          _join(home, ['.npm', '_cacache']),
          'npm Cache',
          'Downloaded packages; re-fetched on next install',
          JunkKind.devCache,
          JunkRisk.regenerable,
        ),
        (
          _join(home, ['.gradle', 'caches']),
          'Gradle Caches',
          'Build dependencies; next Android build re-downloads them',
          JunkKind.devCache,
          JunkRisk.regenerable,
        ),
      ],
      {
        'Xcode DerivedData': (owners: const ['xcode'], elevate: false),
      },
    );
  }

  List<JunkLocation> _linux() {
    final home = _env['HOME'];
    return _build([
      (
        _join(home, ['.cache']),
        'User Cache',
        'Caches apps rebuild on demand',
        JunkKind.appCache,
        JunkRisk.regenerable,
      ),
      (
        _join(home, ['.local', 'share', 'Trash']),
        'Trash',
        'Files you already moved to the trash',
        JunkKind.temp,
        JunkRisk.safe,
      ),
      (
        _join(home, ['.npm', '_cacache']),
        'npm Cache',
        'Downloaded packages; re-fetched on next install',
        JunkKind.devCache,
        JunkRisk.regenerable,
      ),
      (
        _join(home, ['.gradle', 'caches']),
        'Gradle Caches',
        'Build dependencies; next Android build re-downloads them',
        JunkKind.devCache,
        JunkRisk.regenerable,
      ),
    ]);
  }
}
