import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class StorageScanFailure extends Failure {
  const StorageScanFailure(super.message);
}

class FileDeleteFailure extends Failure {
  const FileDeleteFailure(super.message);
}
