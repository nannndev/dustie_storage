import 'package:equatable/equatable.dart';

class SystemDriveLocation extends Equatable {
  final String name;
  final String path;
  final String iconName;

  const SystemDriveLocation({
    required this.name,
    required this.path,
    required this.iconName,
  });

  @override
  List<Object?> get props => [name, path, iconName];
}
