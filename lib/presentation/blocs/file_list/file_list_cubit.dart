import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di.dart';
import '../../../data/models/recording_entry.dart';

part 'file_list_state.dart';

class FileListCubit extends Cubit<FileListState> {
  FileListCubit() : super(const FileListState());

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final settings = DI.settingsService.load();
    final dirPath = settings.outputDir.isEmpty ? _defaultDir() : settings.outputDir;
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      emit(const FileListState(entries: []));
      return;
    }

    // Recordings are organised in year/month/day subdirectories
    // (lihat ScreenRecordingService.start), so we must recurse.
    final files = await dir
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.mp4'))
        .cast<File>()
        .asyncMap(RecordingEntry.fromFile)
        .toList();

    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(FileListState(entries: files));
  }

  Future<void> delete(RecordingEntry entry) async {
    try {
      await File(entry.path).delete();
    } catch (_) {}
    emit(state.copyWith(
      entries: state.entries.where((e) => e.path != entry.path).toList(),
    ));
  }

  Future<void> rename(RecordingEntry entry, String newName) async {
    final dir = File(entry.path).parent.path;
    final sep = Platform.isWindows ? '\\' : '/';
    final newPath = '$dir$sep$newName';
    try {
      await File(entry.path).rename(newPath);
      final newEntry = await RecordingEntry.fromFile(File(newPath));
      final updated = state.entries.map((e) => e.path == entry.path ? newEntry : e).toList();
      emit(state.copyWith(entries: updated));
    } catch (_) {}
  }

  static String _defaultDir() {
    final sep = Platform.isWindows ? '\\' : '/';
    final home = Platform.isWindows
        ? (Platform.environment['USERPROFILE'] ??
            '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}')
        : (Platform.environment['HOME'] ?? '/tmp');
    return '$home${sep}Jasnita Screen Recorder';
  }
}
