import 'dart:io';
import 'dart:typed_data';

import '../../domain/entities/storage_item.dart';

class DuplicateCheck {
  /// Selected files proven byte-identical to a copy that stays on disk.
  final List<StorageItem> confirmed;

  /// Selected files that differ, vanished, or whose group would lose every copy.
  final List<StorageItem> rejected;

  const DuplicateCheck({required this.confirmed, required this.rejected});
}

/// Groups are only name+size guesses; this proves a copy really is redundant before it goes.
/// Sync IO: call from an isolate.
class DuplicateVerifier {
  static const _chunk = 1 << 20;

  static DuplicateCheck verify(
    List<List<StorageItem>> groups,
    Set<String> selected,
  ) {
    final confirmed = <StorageItem>[];
    final rejected = <StorageItem>[];

    for (final group in groups) {
      final picked = group.where((i) => selected.contains(i.path)).toList();
      if (picked.isEmpty) continue;
      final keepers = group.where((i) => !selected.contains(i.path)).toList();
      // Never delete the last copy, even if the user ticked them all.
      if (keepers.isEmpty) {
        rejected.addAll(picked);
        continue;
      }
      for (final item in picked) {
        final match = keepers.any((k) => sameContent(k.path, item.path));
        (match ? confirmed : rejected).add(item);
      }
    }
    return DuplicateCheck(confirmed: confirmed, rejected: rejected);
  }

  /// Byte-for-byte compare, bailing out at the first differing chunk.
  static bool sameContent(String a, String b) {
    if (a == b) return false;
    RandomAccessFile? fa;
    RandomAccessFile? fb;
    try {
      final la = File(a).lengthSync();
      if (la != File(b).lengthSync()) return false;
      fa = File(a).openSync();
      fb = File(b).openSync();
      final ba = Uint8List(_chunk);
      final bb = Uint8List(_chunk);
      var remaining = la;
      while (remaining > 0) {
        final n = fa.readIntoSync(ba);
        final m = fb.readIntoSync(bb);
        if (n != m || n == 0) return false;
        for (var i = 0; i < n; i++) {
          if (ba[i] != bb[i]) return false;
        }
        remaining -= n;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      fa?.closeSync();
      fb?.closeSync();
    }
  }
}
