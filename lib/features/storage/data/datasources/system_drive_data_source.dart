import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/system_drive_location.dart';

abstract class SystemDriveDataSource {
  Future<List<SystemDriveLocation>> getCommonLocations();
  Future<String?> pickCustomDirectory();
}

class SystemDriveDataSourceImpl implements SystemDriveDataSource {
  @override
  Future<List<SystemDriveLocation>> getCommonLocations() async {
    final List<SystemDriveLocation> locations = [];
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';

    // 1. Entire Storage / All Available Drives (Windows C:, D:, etc., macOS Volumes, Linux mounts)
    if (Platform.isMacOS) {
      locations.addAll(await _getMacDrives());
    } else if (Platform.isWindows) {
      locations.addAll(await _getWindowsDrives());
    } else if (Platform.isLinux) {
      locations.addAll(await _getLinuxDrives(home));
    }

    // 2. System Caches & Application Data (Hidden gigabytes hide here!)
    if (Platform.isMacOS && home.isNotEmpty) {
      final libDir = Directory('$home/Library');
      if (await libDir.exists()) {
        locations.add(
          SystemDriveLocation(
            name: 'System Caches & AppData',
            path: libDir.path,
            iconName: 'cached',
          ),
        );
      }
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && await Directory(appData).exists()) {
        locations.add(
          SystemDriveLocation(
            name: 'AppData & Caches',
            path: appData,
            iconName: 'cached',
          ),
        );
      }
    } else if (Platform.isLinux && home.isNotEmpty) {
      final cacheDir = Directory('$home/.cache');
      if (await cacheDir.exists()) {
        locations.add(
          SystemDriveLocation(
            name: '.cache & System Data',
            path: cacheDir.path,
            iconName: 'cached',
          ),
        );
      }
    }

    // 3. User Home Directory (Contains all user files and dotfiles)
    if (home.isNotEmpty && await Directory(home).exists()) {
      locations.add(
        SystemDriveLocation(name: 'Home (~)', path: home, iconName: 'home'),
      );
    }

    // 4. Downloads
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null && await downloadsDir.exists()) {
        locations.add(
          SystemDriveLocation(
            name: 'Downloads',
            path: downloadsDir.path,
            iconName: 'download',
          ),
        );
      } else if (home.isNotEmpty) {
        final fallback = Directory('$home/Downloads');
        if (await fallback.exists()) {
          locations.add(
            SystemDriveLocation(
              name: 'Downloads',
              path: fallback.path,
              iconName: 'download',
            ),
          );
        }
      }
    } catch (_) {}

    // 5. Documents
    try {
      final docDir = await getApplicationDocumentsDirectory();
      if (await docDir.exists()) {
        locations.add(
          SystemDriveLocation(
            name: 'Documents',
            path: docDir.path,
            iconName: 'folder_shared',
          ),
        );
      }
    } catch (_) {}

    // 6. Desktop
    if (home.isNotEmpty) {
      final desktop = Directory('$home/Desktop');
      if (await desktop.exists()) {
        locations.add(
          SystemDriveLocation(
            name: 'Desktop',
            path: desktop.path,
            iconName: 'desktop_windows',
          ),
        );
      }
    }

    return locations;
  }

  Future<List<SystemDriveLocation>> _getWindowsDrives() async {
    final Map<String, String> volumeNames = {};
    final Map<String, int> driveTypes = {};

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Get-CimInstance Win32_LogicalDisk | Select-Object -Property DeviceID, VolumeName, DriveType | ConvertTo-Json',
        ]).timeout(const Duration(milliseconds: 1500));

        if (result.exitCode == 0 && result.stdout != null) {
          final raw = result.stdout.toString().trim();
          if (raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            final items = decoded is List ? decoded : [decoded];
            for (final item in items) {
              if (item is Map) {
                final id = item['DeviceID']?.toString().toUpperCase();
                final vol = item['VolumeName']?.toString().trim();
                final type =
                    int.tryParse(item['DriveType']?.toString() ?? '') ?? 3;
                if (id != null && id.isNotEmpty) {
                  final letter = id.replaceAll(':', '');
                  if (vol != null && vol.isNotEmpty) {
                    volumeNames[letter] = vol;
                  }
                  driveTypes[letter] = type;
                }
              }
            }
          }
        }
      } catch (_) {
        // In case PowerShell is restricted or times out, proceed to letter checks
      }
    }

    return _scanDriveLetters(volumeNames, driveTypes);
  }

  List<SystemDriveLocation> _scanDriveLetters(
    Map<String, String> volumeNames,
    Map<String, int> driveTypes,
  ) {
    final List<SystemDriveLocation> drives = [];

    // Check drives A..Z
    for (int code = 65; code <= 90; code++) {
      final letter = String.fromCharCode(code);
      final drivePath = '$letter:\\';
      try {
        final dir = Directory(drivePath);
        if (dir.existsSync()) {
          final volName = volumeNames[letter];
          final type = driveTypes[letter] ?? 3;

          final String displayName;
          if (volName != null && volName.isNotEmpty) {
            displayName = '$volName ($letter:)';
          } else if (letter == 'C') {
            displayName = 'Entire Disk (C:)';
          } else {
            displayName = 'Local Disk ($letter:)';
          }

          // DriveType: 2 = Removable (USB), 4 = Network, 3 = Fixed HDD/SSD
          final String icon;
          if (type == 2) {
            icon = 'storage';
          } else if (type == 4) {
            icon = 'cloud';
          } else {
            icon = 'hard_drive';
          }

          drives.add(
            SystemDriveLocation(
              name: displayName,
              path: drivePath,
              iconName: icon,
            ),
          );
        }
      } catch (_) {
        // Skip inaccessible drives (e.g. empty CD drive)
      }
    }

    if (drives.isEmpty) {
      drives.add(
        const SystemDriveLocation(
          name: 'Entire Disk (C:)',
          path: 'C:\\',
          iconName: 'hard_drive',
        ),
      );
    }

    return drives;
  }

  Future<List<SystemDriveLocation>> _getMacDrives() async {
    final List<SystemDriveLocation> drives = [
      const SystemDriveLocation(
        name: 'Entire Disk (Mac HD)',
        path: '/',
        iconName: 'hard_drive',
      ),
    ];

    try {
      final volumes = Directory('/Volumes');
      if (await volumes.exists()) {
        await for (final entity in volumes.list(followLinks: false)) {
          if (entity is Directory) {
            final name = entity.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last;
            if (name != 'Macintosh HD') {
              drives.add(
                SystemDriveLocation(
                  name: 'Disk ($name)',
                  path: entity.path,
                  iconName: 'storage',
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    return drives;
  }

  Future<List<SystemDriveLocation>> _getLinuxDrives(String home) async {
    final List<SystemDriveLocation> drives = [
      const SystemDriveLocation(
        name: 'Root Storage (/)',
        path: '/',
        iconName: 'hard_drive',
      ),
    ];

    final username = Platform.environment['USER'] ?? '';
    final mountDirs = [
      Directory('/media'),
      Directory('/mnt'),
      if (username.isNotEmpty) Directory('/media/$username'),
      if (username.isNotEmpty) Directory('/run/media/$username'),
    ];

    for (final mDir in mountDirs) {
      try {
        if (await mDir.exists()) {
          await for (final entity in mDir.list(followLinks: false)) {
            if (entity is Directory) {
              final name = entity.uri.pathSegments
                  .where((s) => s.isNotEmpty)
                  .last;
              if (name.isNotEmpty && !name.startsWith('.')) {
                drives.add(
                  SystemDriveLocation(
                    name: 'Disk ($name)',
                    path: entity.path,
                    iconName: 'storage',
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    return drives;
  }

  @override
  Future<String?> pickCustomDirectory() async {
    return await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Any Drive or Folder to Analyze with Dustie',
    );
  }
}
