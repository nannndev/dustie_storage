import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/elevated_cleaner.dart';
import '../../data/datasources/junk_location_data_source.dart';
import '../../domain/entities/delete_result.dart';
import '../../domain/entities/junk_location.dart';

class QuickCleanState extends Equatable {
  final bool loading;
  final List<JunkLocation> locations;
  final Map<String, JunkMeasurement> measurements;
  final Set<String> selected;
  final Set<String> cleaning;

  /// Last clean outcome per location id, so tiles can explain what was left behind.
  final Map<String, DeleteResult> results;

  /// Lowercased names of running processes, refreshed on load and before cleaning.
  final Set<String> runningProcesses;

  const QuickCleanState({
    this.loading = false,
    this.locations = const [],
    this.measurements = const {},
    this.selected = const {},
    this.cleaning = const {},
    this.results = const {},
    this.runningProcesses = const {},
  });

  bool get isCleaning => cleaning.isNotEmpty;

  int get selectedBytes =>
      selected.fold(0, (sum, id) => sum + (measurements[id]?.bytes ?? 0));

  bool isBlocked(JunkLocation l) => l.isBlockedBy(runningProcesses);

  /// The admin retry only makes sense after a normal clean was refused for permissions.
  bool needsAdmin(JunkLocation l) =>
      l.canElevate &&
      (results[l.id]?.countSkipped(SkipReason.accessDenied) ?? 0) > 0;

  QuickCleanState copyWith({
    bool? loading,
    List<JunkLocation>? locations,
    Map<String, JunkMeasurement>? measurements,
    Set<String>? selected,
    Set<String>? cleaning,
    Map<String, DeleteResult>? results,
    Set<String>? runningProcesses,
  }) {
    return QuickCleanState(
      loading: loading ?? this.loading,
      locations: locations ?? this.locations,
      measurements: measurements ?? this.measurements,
      selected: selected ?? this.selected,
      cleaning: cleaning ?? this.cleaning,
      results: results ?? this.results,
      runningProcesses: runningProcesses ?? this.runningProcesses,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    locations,
    measurements,
    selected,
    cleaning,
    results,
    runningProcesses,
  ];
}

class QuickCleanCubit extends Cubit<QuickCleanState> {
  final JunkLocationDataSource dataSource;

  QuickCleanCubit({required this.dataSource}) : super(const QuickCleanState());

  bool _started = false;

  /// First visit to the tab triggers discovery; app startup stays free of process/disk work.
  void ensureLoaded() {
    if (_started) return;
    _started = true;
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final (locations, running) = await (
      dataSource.findLocations(),
      dataSource.runningProcesses(),
    ).wait;
    if (isClosed) return;
    emit(
      QuickCleanState(
        locations: locations,
        runningProcesses: running,
        // Only no-risk locations start ticked; regenerable caches are opt-in.
        selected: {
          for (final l in locations)
            if (l.risk == JunkRisk.safe) l.id,
        },
      ),
    );
    await Future.wait(locations.map(_measure));
  }

  Future<void> refreshProcesses() async {
    final running = await dataSource.runningProcesses();
    if (!isClosed) emit(state.copyWith(runningProcesses: running));
  }

  Future<void> _measure(JunkLocation l) async {
    final m = await dataSource.measure(l);
    if (isClosed) return;
    emit(state.copyWith(measurements: {...state.measurements, l.id: m}));
  }

  void toggle(String id) {
    final next = Set<String>.from(state.selected);
    next.contains(id) ? next.remove(id) : next.add(id);
    emit(state.copyWith(selected: next));
  }

  /// Returns the combined result so the caller can show a summary.
  Future<DeleteResult?> cleanSelected() async {
    final targets = state.locations
        .where((l) => state.selected.contains(l.id))
        .toList();
    if (targets.isEmpty || state.isCleaning) return null;
    emit(state.copyWith(cleaning: {for (final t in targets) t.id}));

    var total = const DeleteResult();
    for (final t in targets) {
      final r = await dataSource.clean(t);
      total = total.merge(r);
      if (isClosed) return total;
      emit(
        state.copyWith(
          cleaning: Set.of(state.cleaning)..remove(t.id),
          results: {...state.results, t.id: r},
        ),
      );
      await _measure(t);
    }
    await refreshProcesses();
    return total;
  }

  /// Null when the user dismissed the UAC prompt.
  Future<ElevatedCleanResult?> cleanAsAdmin(JunkLocation l) async {
    if (state.isCleaning) return null;
    emit(state.copyWith(cleaning: {l.id}));
    final r = await dataSource.cleanElevated(l);
    if (isClosed) return r;
    final results = Map.of(state.results);
    // A successful elevated pass supersedes the earlier "access denied" tally.
    if (r != null) results.remove(l.id);
    emit(state.copyWith(cleaning: const {}, results: results));
    await _measure(l);
    return r;
  }
}
