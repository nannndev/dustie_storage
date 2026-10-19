import 'package:equatable/equatable.dart';

import '../../../../core/utils/file_size_formatter.dart';

enum JunkKind { temp, browserCache, crashDumps, logs, appCache, devCache }

enum JunkRisk {
  /// Nothing needs it back; apps never notice.
  safe,

  /// Rebuilt or re-downloaded on next use, so the first run afterwards is slower.
  regenerable,
}

/// A well-known folder whose contents can be cleared; the folder itself is always kept.
class JunkLocation extends Equatable {
  final String id;
  final String name;
  final String description;
  final String path;
  final JunkKind kind;
  final JunkRisk risk;

  /// Lowercased process names that keep these files open (e.g. chrome.exe); clean only fully once they exit.
  final List<String> ownerProcesses;

  /// Offer an elevated (UAC) retry when files are refused for lack of admin rights.
  final bool canElevate;

  const JunkLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.path,
    required this.kind,
    required this.risk,
    this.ownerProcesses = const [],
    this.canElevate = false,
  });

  bool isBlockedBy(Set<String> running) => ownerProcesses.any(running.contains);

  @override
  List<Object?> get props => [id, path];
}

class JunkMeasurement {
  final int bytes;
  final int fileCount;

  const JunkMeasurement({required this.bytes, required this.fileCount});

  String get formattedSize => FileSizeFormatter.format(bytes);
}
