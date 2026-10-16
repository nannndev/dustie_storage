import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/navigation/presentation/cubit/navigation_cubit.dart';
import 'features/storage/data/datasources/local_file_system_data_source.dart';
import 'features/storage/data/datasources/system_drive_data_source.dart';
import 'features/storage/data/repositories/storage_repository_impl.dart';
import 'features/storage/domain/repositories/storage_repository.dart';
import 'features/storage/presentation/bloc/storage_bloc.dart';
import 'features/storage/presentation/bloc/storage_event.dart';
import 'features/storage/presentation/cubit/storage_filter_cubit.dart';
import 'features/storage/presentation/views/main_dashboard_view.dart';

class DustieStorageApp extends StatelessWidget {
  const DustieStorageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<StorageRepository>(
          create: (context) => StorageRepositoryImpl(
            localDataSource: LocalFileSystemDataSourceImpl(),
            systemDriveDataSource: SystemDriveDataSourceImpl(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>(create: (context) => ThemeCubit()),
          BlocProvider<NavigationCubit>(create: (context) => NavigationCubit()),
          BlocProvider<StorageFilterCubit>(
            create: (context) => StorageFilterCubit(),
          ),
          BlocProvider<StorageBloc>(
            create: (context) =>
                StorageBloc(repository: context.read<StorageRepository>())
                  ..add(const LoadCommonLocationsRequested()),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            AppColors.isDark = (themeMode == ThemeMode.dark);

            return MaterialApp(
              title: 'Dustie Storage',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              // Non-const + keyed so every AppColors getter re-reads isDark on toggle
              home: MainDashboardView(key: ValueKey(themeMode)),
            );
          },
        ),
      ),
    );
  }
}
