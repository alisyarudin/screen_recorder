import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'core/di.dart';
import 'presentation/blocs/recording/recording_bloc.dart';
import 'presentation/blocs/settings/settings_cubit.dart';
import 'presentation/blocs/file_list/file_list_cubit.dart';
import 'presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DI.init();

  await windowManager.ensureInitialized();
  final settings = DI.settingsService.load();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: const Size(860, 600),
      minimumSize: const Size(640, 480),
      title: 'Screen Recorder',
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.setAlwaysOnTop(settings.alwaysOnTop);
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const ScreenRecorderApp());
}

class ScreenRecorderApp extends StatelessWidget {
  const ScreenRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => RecordingBloc()),
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(create: (_) => FileListCubit()),
      ],
      child: MaterialApp(
        title: 'Screen Recorder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0C7A8C),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF45BDCE),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
