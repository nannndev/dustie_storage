import 'package:equatable/equatable.dart';

import '../../domain/entities/scan_progress.dart';
import '../../domain/entities/storage_summary.dart';
import '../../domain/entities/system_drive_location.dart';

enum StorageStatus { initial, loading, scanning, success, failure }

class StorageState extends Equatable {
  final StorageStatus status;
  final String currentPath;
  final List<SystemDriveLocation> locations;
  final StorageSummary summary;
  final String statusMessage;
  final String? errorMessage;
  final String? notificationMessage;
  final Map<String, StorageSummary> cache;
  final Set<String> scanningPaths;

  /// Live totals for the scan of [currentPath]; null until the first worker report.
  final ScanProgress? scanProgress;

  const StorageState({
    this.status = StorageStatus.initial,
    this.currentPath = '',
    this.locations = const [],
    required this.summary,
    this.statusMessage = '',
    this.errorMessage,
    this.notificationMessage,
    this.cache = const {},
    this.scanningPaths = const {},
    this.scanProgress,
  });

  factory StorageState.initial() {
    return StorageState(summary: StorageSummary.empty());
  }

  bool get isScanning => status == StorageStatus.scanning;
  bool isPathScanning(String path) => scanningPaths.contains(path);

  StorageState copyWith({
    StorageStatus? status,
    String? currentPath,
    List<SystemDriveLocation>? locations,
    StorageSummary? summary,
    String? statusMessage,
    String? errorMessage,
    bool clearError = false,
    String? notificationMessage,
    bool clearNotification = false,
    Map<String, StorageSummary>? cache,
    Set<String>? scanningPaths,
    ScanProgress? scanProgress,
    bool clearScanProgress = false,
  }) {
    return StorageState(
      status: status ?? this.status,
      currentPath: currentPath ?? this.currentPath,
      locations: locations ?? this.locations,
      summary: summary ?? this.summary,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notificationMessage: clearNotification
          ? null
          : (notificationMessage ?? this.notificationMessage),
      cache: cache ?? this.cache,
      scanningPaths: scanningPaths ?? this.scanningPaths,
      scanProgress: clearScanProgress
          ? null
          : (scanProgress ?? this.scanProgress),
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentPath,
    locations,
    summary,
    statusMessage,
    errorMessage,
    notificationMessage,
    cache,
    scanningPaths,
    scanProgress,
  ];
}
