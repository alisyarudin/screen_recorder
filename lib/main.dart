import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'core/di.dart';
import 'presentation/blocs/recording/recording_bloc.dart';
import 'presentation/blocs/settings/settings_cubit.dart';
import 'presentation/blocs/file_list/file_list_cubit.dart';
import 'presentation/blocs/monitoring/monitoring_cubit.dart';
import 'presentation/blocs/history/history_cubit.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/widgets/app_dialog.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DI.init();
  } on FileSystemException catch (e) {
    // errno 35 = EAGAIN: Hive lock gagal karena instance lain sudah berjalan.
    // LSMultipleInstancesProhibited di Info.plist seharusnya mencegah ini,
    // tapi jika lolos (mis. debug mode), exit saja — instance lama tetap aktif.
    if (e.osError?.errorCode == 35) {
      exit(0);
    }
    rethrow;
  }

  // Mulai server polling jika URL dikonfigurasi
  final settings = DI.settingsService.load();
  if (settings.serverControlUrl.isNotEmpty) {
    DI.adminService.startServerPolling(settings.serverControlUrl);
  }

  // Tangani perintah dari server
  DI.adminService.serverCommands.listen((command) {
    switch (command) {
      case 'exit':
        DI.adminService.quitApp();
    }
  });

  // Tray "Keluar" (Windows) — native meminta UI menjalankan password flow.
  DI.adminService.quitRequested.listen((_) => _handleQuitRequested());

  await windowManager.ensureInitialized();
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

Future<void> _handleQuitRequested() async {
  final needsPassword = await DI.adminService.hasAdminPassword();
  if (!needsPassword) {
    await DI.adminService.quitApp();
    return;
  }
  // Ambil context setelah async gap — kalau widget tree sudah teardown,
  // langsung quit tanpa dialog.
  final ctx = _navigatorKey.currentContext;
  if (ctx == null) {
    await DI.adminService.quitApp();
    return;
  }
  final verified = await showPasswordDialog(
    ctx,
    title: 'Keluar dari Screen Recorder?',
    subtitle: 'Masukkan password admin untuk menutup aplikasi.',
    confirmLabel: 'Keluar',
  );
  if (verified) await DI.adminService.quitApp();
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
        BlocProvider(create: (_) => MonitoringCubit()),
        BlocProvider(create: (_) => HistoryCubit()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
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
        home: const MainShell(),
      ),
    );
  }
}
