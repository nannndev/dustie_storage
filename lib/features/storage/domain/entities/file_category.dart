import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum FileCategory {
  video,
  image,
  audio,
  document,
  archive,
  installer,
  code,
  other,
}

extension FileCategoryExt on FileCategory {
  String get label {
    switch (this) {
      case FileCategory.video:
        return 'Videos';
      case FileCategory.image:
        return 'Images';
      case FileCategory.audio:
        return 'Audio';
      case FileCategory.document:
        return 'Documents';
      case FileCategory.archive:
        return 'Archives';
      case FileCategory.installer:
        return 'Installers';
      case FileCategory.code:
        return 'Code & Dev';
      case FileCategory.other:
        return 'Others';
    }
  }

  String get emoji {
    switch (this) {
      case FileCategory.video:
        return '🎬';
      case FileCategory.image:
        return '🖼️';
      case FileCategory.audio:
        return '🎵';
      case FileCategory.document:
        return '📄';
      case FileCategory.archive:
        return '📦';
      case FileCategory.installer:
        return '💿';
      case FileCategory.code:
        return '💻';
      case FileCategory.other:
        return '📁';
    }
  }

  IconData get icon {
    switch (this) {
      case FileCategory.video:
        return Icons.videocam_rounded;
      case FileCategory.image:
        return Icons.image_rounded;
      case FileCategory.audio:
        return Icons.headphones_rounded;
      case FileCategory.document:
        return Icons.description_rounded;
      case FileCategory.archive:
        return Icons.inventory_2_rounded;
      case FileCategory.installer:
        return Icons.install_desktop_rounded;
      case FileCategory.code:
        return Icons.code_rounded;
      case FileCategory.other:
        return Icons.folder_open_rounded;
    }
  }

  Color get color {
    switch (this) {
      case FileCategory.video:
        return AppColors.catVideo;
      case FileCategory.image:
        return AppColors.catImage;
      case FileCategory.audio:
        return AppColors.catAudio;
      case FileCategory.document:
        return AppColors.catDocument;
      case FileCategory.archive:
        return AppColors.catArchive;
      case FileCategory.installer:
        return AppColors.catInstaller;
      case FileCategory.code:
        return AppColors.catCode;
      case FileCategory.other:
        return AppColors.catOther;
    }
  }

  static FileCategory fromExtension(String ext) {
    final cleanExt = ext.toLowerCase().replaceFirst('.', '');
    
    // Videos
    if (const {'mp4', 'mkv', 'mov', 'avi', 'wmv', 'flv', 'webm', 'm4v', '3gp'}.contains(cleanExt)) {
      return FileCategory.video;
    }
    // Images
    if (const {'jpg', 'jpeg', 'png', 'gif', 'svg', 'webp', 'bmp', 'tiff', 'heic', 'ico', 'raw'}.contains(cleanExt)) {
      return FileCategory.image;
    }
    // Audio
    if (const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma', 'alac'}.contains(cleanExt)) {
      return FileCategory.audio;
    }
    // Documents
    if (const {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv', 'md', 'epub'}.contains(cleanExt)) {
      return FileCategory.document;
    }
    // Archives
    if (const {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso', 'tgz'}.contains(cleanExt)) {
      return FileCategory.archive;
    }
    // Installers
    if (const {'dmg', 'pkg', 'exe', 'msi', 'deb', 'rpm', 'appimage', 'apk', 'ipa'}.contains(cleanExt)) {
      return FileCategory.installer;
    }
    // Code & Dev
    if (const {'dart', 'js', 'ts', 'jsx', 'tsx', 'py', 'rs', 'go', 'java', 'c', 'cpp', 'h', 'swift', 'kt', 'html', 'css', 'scss', 'json', 'yaml', 'yml', 'xml', 'sql', 'sh'}.contains(cleanExt)) {
      return FileCategory.code;
    }

    return FileCategory.other;
  }
}
