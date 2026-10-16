import 'package:equatable/equatable.dart';
import '../../domain/entities/storage_summary.dart';
import '../../domain/entities/system_drive_location.dart';

enum StorageStatus {
  initial,
  loading,
  scanning,
  success,
  failure,
}

class StorageState extends Equatable {
  final StorageStatus status;
  final String currentPath;
  final List<SystemDriveLocation> locations;
  final StorageSummary summary;
  final String statusMessage;
  final String? errorMessage;
  final String? notificationMessage;

  const StorageState({
    this.status = StorageStatus.initial,
    this.currentPath = '',
    this.locations = const [],
    required this.summary,
    this.statusMessage = '',
    this.errorMessage,
    this.notificationMessage,
  });

  factory StorageState.initial() {
    return StorageState(
      summary: StorageSummary.empty(),
    );
  }

  bool get isScanning => status == StorageStatus.scanning;

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
  }) {
    return StorageState(
      status: status ?? this.status,
      currentPath: currentPath ?? this.currentPath,
      locations: locations ?? this.locations,
      summary: summary ?? this.summary,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notificationMessage: clearNotification ? null : (notificationMessage ?? this.notificationMessage),
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
      ];
}
