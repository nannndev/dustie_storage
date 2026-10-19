/// Folders whose files Dustie must never suggest or delete: toolchains, package caches, the OS.
///
/// Losing these doesn't free useful space, it just breaks builds or the system. Pure string
/// matching (no IO) so it runs inside scan isolates and summary rebuilds for free.
class ProtectedPaths {
  /// Path segments (lowercase, '/'-separated) that mark a protected tree anywhere in a path.
  static const _segments = [
    // Dart / Flutter
    '/pub/cache/', '/.pub-cache/', '/flutter/bin/cache/', '/.dart_tool/',
    // Other language toolchains & package stores
    '/.gradle/wrapper/', '/.m2/repository/', '/.cargo/registry/',
    '/.rustup/', '/go/pkg/mod/', '/.nuget/packages/', '/sdk/platforms/',
    '/android/sdk/', '/.android/avd/',
    // Version control internals
    '/.git/', '/.svn/', '/.hg/',
    // Windows system
    '/windows/system32/', '/windows/syswow64/', '/windows/winsxs/',
    '/program files/', '/program files (x86)/', '/programdata/microsoft/',
    // macOS system
    '/library/frameworks/', '/applications/xcode.app/',
  ];

  static String _norm(String path) =>
      '${path.replaceAll('\\', '/').toLowerCase()}/';

  static bool isProtected(String path) {
    final n = _norm(path);
    // Root-anchored macOS system dirs only; "/system/" elsewhere is a normal folder name.
    if (n.startsWith('/system/') || n.startsWith('/usr/')) return true;
    return _segments.any(n.contains);
  }
}
