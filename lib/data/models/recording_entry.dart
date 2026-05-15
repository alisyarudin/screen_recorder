import 'dart:io';

class RecordingEntry {
  final String path;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
  final Duration? duration; // null jika belum bisa dibaca

  const RecordingEntry({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
    this.duration,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<RecordingEntry> fromFile(File file) async {
    final stat = await file.stat();
    return RecordingEntry(
      path: file.path,
      name: file.uri.pathSegments.last,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  RecordingEntry copyWith({String? name}) => RecordingEntry(
        path: path,
        name: name ?? this.name,
        createdAt: createdAt,
        sizeBytes: sizeBytes,
        duration: duration,
      );
}
