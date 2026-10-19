import 'package:dustie_storage/features/storage/data/datasources/system_drive_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SystemDriveDataSourceImpl returns available system drive locations',
    () async {
      final dataSource = SystemDriveDataSourceImpl();
      final locations = await dataSource.getCommonLocations();

      expect(locations, isNotEmpty);
      // Should contain at least one drive/root location
      expect(
        locations.any(
          (l) =>
              l.name.contains('Disk') ||
              l.name.contains('Root') ||
              l.name.contains('Volume'),
        ),
        isTrue,
      );
    },
  );
}
