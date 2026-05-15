part of 'file_list_cubit.dart';

class FileListState {
  final List<RecordingEntry> entries;
  final bool loading;

  const FileListState({this.entries = const [], this.loading = false});

  FileListState copyWith({List<RecordingEntry>? entries, bool? loading}) => FileListState(
        entries: entries ?? this.entries,
        loading: loading ?? false,
      );
}
