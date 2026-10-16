import 'package:equatable/equatable.dart';

import 'file_category.dart';

enum SortOption { sizeDesc, sizeAsc, dateDesc, dateAsc, nameAsc }

extension SortOptionExt on SortOption {
  String get label {
    switch (this) {
      case SortOption.sizeDesc:
        return 'Largest First';
      case SortOption.sizeAsc:
        return 'Smallest First';
      case SortOption.dateDesc:
        return 'Newest First';
      case SortOption.dateAsc:
        return 'Oldest First (Dustiest)';
      case SortOption.nameAsc:
        return 'Name (A-Z)';
    }
  }
}

class StorageFilter extends Equatable {
  final FileCategory? category;
  final int minSizeBytes;
  final int? minAgeDays;
  final String searchQuery;
  final SortOption sortOption;
  final bool filesOnly;
  final bool showHiddenOnly;

  const StorageFilter({
    this.category,
    this.minSizeBytes = 0,
    this.minAgeDays,
    this.searchQuery = '',
    this.sortOption = SortOption.sizeDesc,
    this.filesOnly = false,
    this.showHiddenOnly = false,
  });

  StorageFilter copyWith({
    FileCategory? category,
    bool clearCategory = false,
    int? minSizeBytes,
    int? minAgeDays,
    bool clearAge = false,
    String? searchQuery,
    SortOption? sortOption,
    bool? filesOnly,
    bool? showHiddenOnly,
  }) {
    return StorageFilter(
      category: clearCategory ? null : (category ?? this.category),
      minSizeBytes: minSizeBytes ?? this.minSizeBytes,
      minAgeDays: clearAge ? null : (minAgeDays ?? this.minAgeDays),
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      filesOnly: filesOnly ?? this.filesOnly,
      showHiddenOnly: showHiddenOnly ?? this.showHiddenOnly,
    );
  }

  @override
  List<Object?> get props => [
    category,
    minSizeBytes,
    minAgeDays,
    searchQuery,
    sortOption,
    filesOnly,
    showHiddenOnly,
  ];
}
