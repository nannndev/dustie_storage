import 'package:equatable/equatable.dart';
import '../../../../core/utils/file_size_formatter.dart';
import 'file_category.dart';

class StorageItem extends Equatable {
  final String path;
  final String name;
  final int size; // In bytes
  final bool isDirectory;
  final DateTime modified;
  final String extension;
  final FileCategory category;
  final int childCount;

  const StorageItem({
    required this.path,
    required this.name,
    required this.size,
    required this.isDirectory,
    required this.modified,
    required this.extension,
    required this.category,
    this.childCount = 0,
  });

  int get ageInDays => DateTime.now().difference(modified).inDays;

  bool get isDusty => ageInDays >= 180;

  bool get isHidden => name.startsWith('.');

  String get formattedSize => FileSizeFormatter.format(size);

  @override
  List<Object?> get props => [
        path,
        name,
        size,
        isDirectory,
        modified,
        extension,
        category,
        childCount,
      ];
}
