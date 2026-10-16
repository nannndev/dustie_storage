import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/file_category.dart';
import '../../domain/entities/storage_filter.dart';
import '../../domain/entities/storage_item.dart';

class StorageFilterCubit extends Cubit<StorageFilter> {
  StorageFilterCubit() : super(const StorageFilter());

  void setCategory(FileCategory? category) {
    emit(state.copyWith(category: category, clearCategory: category == null));
  }

  void setMinSizeBytes(int bytes) {
    emit(state.copyWith(minSizeBytes: bytes));
  }

  void setMinAgeDays(int? days) {
    emit(state.copyWith(minAgeDays: days, clearAge: days == null));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void setSortOption(SortOption sort) {
    emit(state.copyWith(sortOption: sort));
  }

  void toggleHiddenOnly() {
    emit(state.copyWith(showHiddenOnly: !state.showHiddenOnly));
  }

  void resetFilters() {
    emit(const StorageFilter());
  }

  List<StorageItem> applyFilter(List<StorageItem> allItems) {
    final query = state.searchQuery.toLowerCase();

    var filtered = allItems.where((item) {
      if (state.showHiddenOnly && !item.isHidden) {
        return false;
      }
      if (state.category != null && item.category != state.category) {
        return false;
      }
      if (item.size < state.minSizeBytes) {
        return false;
      }
      if (state.minAgeDays != null && item.ageInDays < state.minAgeDays!) {
        return false;
      }
      // Path already contains the name, so one lowercase per item is enough
      if (query.isNotEmpty && !item.path.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    switch (state.sortOption) {
      case SortOption.sizeDesc:
        break; // source list is already largest-first
      case SortOption.sizeAsc:
        filtered.sort((a, b) => a.size.compareTo(b.size));
        break;
      case SortOption.dateDesc:
        filtered.sort((a, b) => b.modified.compareTo(a.modified));
        break;
      case SortOption.dateAsc:
        filtered.sort((a, b) => a.modified.compareTo(b.modified));
        break;
      case SortOption.nameAsc:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }

    return filtered;
  }
}
