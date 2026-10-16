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

    // 1. Entire Storage / Root Drive (Macintosh HD, C:\, /)
    if (Platform.isMacOS) {
      locations.add(
        const SystemDriveLocation(
          name: 'Entire Disk (Mac HD)',
          path: '/',
          iconName: 'hard_drive',
        ),
      );
    } else if (Platform.isWindows) {
      locations.add(
        const SystemDriveLocation(
          name: 'Entire Disk (C:)',
          path: 'C:\\',
          iconName: 'hard_drive',
        ),
      );
    } else if (Platform.isLinux) {
      locations.add(
        const SystemDriveLocation(
          name: 'Root Storage (/)',
          path: '/',
          iconName: 'hard_drive',
        ),
      );
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

    // 7. External Volumes / Drives
    if (Platform.isMacOS) {
      final volumes = Directory('/Volumes');
      if (await volumes.exists()) {
        locations.add(
          const SystemDriveLocation(
            name: 'Volumes & USBs',
            path: '/Volumes',
            iconName: 'storage',
          ),
        );
      }
    }

    return locations;
  }

  @override
  Future<String?> pickCustomDirectory() async {
    return await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Any Drive or Folder to Analyze with Dustie',
    );
  }
}
