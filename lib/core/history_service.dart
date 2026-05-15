import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/history_entry.dart';

class HistoryService {
  static const _boxName = 'history';
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveSession(HistorySession session) async {
    final key = _dateKey(session.startTime);
    final existing = _loadDay(key);
    final sessions =
        existing != null ? [...existing.sessions, session] : [session];
    await _box.put(key, sessions.map((s) => s.toMap()).toList());
  }

  HistoryDay? getDay(String dateKey) => _loadDay(dateKey);

  List<HistoryDay> getRecentDays(int count) {
    final days = <HistoryDay>[];
    final today = DateTime.now();
    for (int i = 0; i < count; i++) {
      final d = today.subtract(Duration(days: i));
      final key = _dateKey(d);
      final day = _loadDay(key) ??
          HistoryDay(
            dateKey: key,
            date: DateTime(d.year, d.month, d.day),
            sessions: [],
          );
      days.add(day);
    }
    return days;
  }

  HistoryDay? _loadDay(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final date = DateTime.parse(key);
    final sessions =
        (raw as List).map((e) => HistorySession.fromMap(e as Map)).toList();
    return HistoryDay(dateKey: key, date: date, sessions: sessions);
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
