import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../data/models/history_entry.dart';
import '../blocs/history/history_cubit.dart';

// ─── App colour palette ───────────────────────────────────────────────────────

const _kAppColors = {
  'Google Chrome': Color(0xFF4285F4),
  'Microsoft Teams': Color(0xFF6264A7),
  'Visual Studio Code': Color(0xFF0078D4),
  'Slack': Color(0xFF611F69),
  'Notepad': Color(0xFFFFB900),
  'Microsoft Outlook': Color(0xFF0078D4),
};

Color _colorFor(String appName) => _kAppColors[appName] ?? Colors.grey;
String _initialFor(String appName) =>
    appName.isNotEmpty ? appName[0].toUpperCase() : '?';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtHM(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${h}j ${m}m';
}

String _fmtHMS(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime date, DateTime today) {
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  return days[date.weekday - 1];
}

String _fullDateLabel(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

// ─── History Screen ───────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _range = 'bulan';

  @override
  void initState() {
    super.initState();
    context.read<HistoryCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        return Column(
          children: [
            _PageHeader(c: c, range: _range, onRangeChange: (v) => setState(() => _range = v)),
            Divider(height: 1, thickness: 1, color: c.borderSoft),
            Expanded(
              child: state.isLoading
                  ? Center(child: CircularProgressIndicator(color: c.accent))
                  : _HistoryBody(c: c, days: state.days),
            ),
          ],
        );
      },
    );
  }
}

// ─── Page Header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final AppColors c;
  final String range;
  final ValueChanged<String> onRangeChange;

  const _PageHeader({required this.c, required this.range, required this.onRangeChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Riwayat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  letterSpacing: -0.15,
                ),
              ),
              Text(
                'Data aktivitas tersimpan per hari · klik baris hari untuk lihat detail',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
          const Spacer(),
          _SegmentedControl(
            c: c,
            options: const [('bulan', 'Bulan ini'), ('triwulan', 'Triwulan'), ('tahun', 'Tahun')],
            selected: range,
            onSelect: onRangeChange,
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.download_outlined, size: 14, color: c.textMuted),
            label: Text('Ekspor CSV', style: TextStyle(fontSize: 12, color: c.textMuted)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Segmented control ────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  final AppColors c;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentedControl({
    required this.c,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.bgMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final active = opt.$1 == selected;
          return GestureDetector(
            onTap: () => onSelect(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                boxShadow: active
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                    : null,
              ),
              child: Text(
                opt.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  color: active ? c.text : c.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _HistoryBody extends StatelessWidget {
  final AppColors c;
  final List<HistoryDay> days;

  const _HistoryBody({required this.c, required this.days});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _CalendarHeatmap(c: c, days: days),
        const SizedBox(height: 16),
        _SummaryTiles(c: c, days: days),
        const SizedBox(height: 20),
        _SectionLabel(c: c, label: 'Per hari'),
        const SizedBox(height: 8),
        _DayList(c: c, days: days),
        const SizedBox(height: 16),
        _InfoBanner(c: c),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final AppColors c;
  final String label;

  const _SectionLabel({required this.c, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.07,
        color: c.textSubtle,
      ),
    );
  }
}

// ─── Calendar Heatmap ─────────────────────────────────────────────────────────

class _CalendarHeatmap extends StatelessWidget {
  final AppColors c;
  final List<HistoryDay> days; // index 0 = today, up to 35

  const _CalendarHeatmap({required this.c, required this.days});

  Color _cellColor(double intensity) {
    if (intensity <= 0) return c.bgMuted;
    if (intensity < 0.25) return c.accent.withValues(alpha: 0.18);
    if (intensity < 0.50) return c.accent.withValues(alpha: 0.38);
    if (intensity < 0.75) return c.accent.withValues(alpha: 0.62);
    return c.accent;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    // Build a 5×7 grid (col=week, row=weekday Mon-Sun).
    // days[0] = today. We need to place each day into the right cell.
    // Determine the starting Monday of the grid (5 weeks back from today's week).
    final todayWeekday = today.weekday; // 1=Mon, 7=Sun
    final thisMonday = today.subtract(Duration(days: todayWeekday - 1));
    final gridStart = thisMonday.subtract(const Duration(days: 28)); // 4 weeks back = 5 weeks total

    // Map dateKey → intensity
    final intensityMap = <String, double>{};
    for (final day in days) {
      intensityMap[day.dateKey] = day.activityIntensity;
    }

    String dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktivitas 5 minggu terakhir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  Text(
                    'Intensitas penggunaan harian',
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  Text('Sedikit', style: TextStyle(fontSize: 10, color: c.textSubtle)),
                  const SizedBox(width: 4),
                  ...([0.0, 0.15, 0.35, 0.60, 1.0]).map((v) => Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                          color: _cellColor(v),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                  const SizedBox(width: 4),
                  Text('Banyak', style: TextStyle(fontSize: 10, color: c.textSubtle)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day-of-week labels + grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row labels
              Column(
                children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((lbl) {
                  return SizedBox(
                    height: 22,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          lbl,
                          style: TextStyle(fontSize: 9, color: c.textSubtle),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 5-column × 7-row grid
              Expanded(
                child: Row(
                  children: List.generate(5, (col) {
                    return Expanded(
                      child: Column(
                        children: List.generate(7, (row) {
                          final cellDate = gridStart.add(Duration(days: col * 7 + row));
                          final key = dateKey(cellDate);
                          final intensity = intensityMap[key] ?? 0.0;
                          final isToday = key == dateKey(today);
                          final isFuture = cellDate.isAfter(today);

                          return Container(
                            height: 22,
                            margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: isFuture ? c.bgMuted.withValues(alpha: 0.4) : _cellColor(intensity),
                              borderRadius: BorderRadius.circular(4),
                              border: isToday
                                  ? Border.all(color: c.accent, width: 1.5)
                                  : null,
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Summary Tiles ────────────────────────────────────────────────────────────

class _SummaryTiles extends StatelessWidget {
  final AppColors c;
  final List<HistoryDay> days;

  const _SummaryTiles({required this.c, required this.days});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = days.where((d) => d.date.month == now.month && d.date.year == now.year);

    // Total hours this month
    final totalActive = thisMonth.fold(Duration.zero, (s, d) => s + d.totalActive);

    // Longest day this month
    Duration longestDay = Duration.zero;
    for (final d in thisMonth) {
      if (d.totalActive > longestDay) longestDay = d.totalActive;
    }

    // Avg active % (of days with sessions)
    final daysWithData = thisMonth.where((d) => d.sessions.isNotEmpty).toList();
    double avgPct = 0;
    if (daysWithData.isNotEmpty) {
      final totalSession = daysWithData.fold(Duration.zero, (s, d) {
        return s + d.sessions.fold(Duration.zero, (ss, se) => ss + se.totalDuration);
      });
      final totalAct = daysWithData.fold(Duration.zero, (s, d) => s + d.totalActive);
      avgPct = totalSession.inSeconds > 0
          ? (totalAct.inSeconds / totalSession.inSeconds * 100).clamp(0, 100)
          : 0;
    }

    // Total recordings
    final totalRec = thisMonth.fold(0, (s, d) => s + d.totalRecordings);

    return Row(
      children: [
        _StatTile(
          c: c,
          label: 'Total bulan ini',
          value: _fmtHM(totalActive),
          sublabel: 'waktu aktif',
        ),
        const SizedBox(width: 10),
        _StatTile(
          c: c,
          label: 'Hari terpanjang',
          value: _fmtHM(longestDay),
          sublabel: 'waktu aktif terlama',
        ),
        const SizedBox(width: 10),
        _StatTile(
          c: c,
          label: 'Rata-rata aktif',
          value: '${avgPct.toStringAsFixed(0)}%',
          sublabel: 'dari total sesi',
          accent: c.success,
        ),
        const SizedBox(width: 10),
        _StatTile(
          c: c,
          label: 'Total rekaman',
          value: '$totalRec',
          sublabel: 'file rekaman',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final AppColors c;
  final String label;
  final String value;
  final String sublabel;
  final Color? accent;

  const _StatTile({
    required this.c,
    required this.label,
    required this.value,
    required this.sublabel,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.bgSubtle,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06,
                color: c.textSubtle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: accent ?? c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(fontSize: 11, color: c.textSubtle),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day List ─────────────────────────────────────────────────────────────────

class _DayList extends StatefulWidget {
  final AppColors c;
  final List<HistoryDay> days;

  const _DayList({required this.c, required this.days});

  @override
  State<_DayList> createState() => _DayListState();
}

class _DayListState extends State<_DayList> {
  int _expandedIdx = -1;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final days = widget.days;

    return Container(
      decoration: BoxDecoration(
        color: c.bgSubtle,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(days.length, (i) {
          return _DayCard(
            c: c,
            day: days[i],
            expanded: _expandedIdx == i,
            onToggle: days[i].sessions.isEmpty
                ? null
                : () => setState(() => _expandedIdx = _expandedIdx == i ? -1 : i),
            isLast: i == days.length - 1,
          );
        }),
      ),
    );
  }
}

// ─── Day Card ─────────────────────────────────────────────────────────────────

class _DayCard extends StatefulWidget {
  final AppColors c;
  final HistoryDay day;
  final bool expanded;
  final VoidCallback? onToggle;
  final bool isLast;

  const _DayCard({
    required this.c,
    required this.day,
    required this.expanded,
    required this.onToggle,
    required this.isLast,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final day = widget.day;
    final today = DateTime.now();
    final hasData = day.sessions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collapsed row
        MouseRegion(
          cursor: hasData ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: hasData ? (_) => setState(() => _hovered = true) : null,
          onExit: hasData ? (_) => setState(() => _hovered = false) : null,
          child: GestureDetector(
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              color: _hovered && hasData
                  ? c.bgHover
                  : widget.expanded
                      ? c.bgActive
                      : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Col 1: date info (130px)
                  SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dayLabel(day.date, today),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        Text(
                          _fullDateLabel(day.date),
                          style: TextStyle(fontSize: 10, color: c.textMuted),
                        ),
                        if (hasData) ...[
                          Text(
                            '${day.sessions.length} sesi',
                            style: TextStyle(fontSize: 10, color: c.textSubtle),
                          ),
                          Text(
                            '${_fmtTime(day.sessions.first.startTime)} – ${_fmtTime(day.sessions.last.endTime)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: c.textSubtle,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Col 2: app stack + names
                  Expanded(
                    child: hasData
                        ? _AppStack(c: c, apps: day.topApps.take(5).toList())
                        : Text(
                            'Tidak ada aktivitas',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textFaint,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),

                  // Col 3: day stats (220px)
                  if (hasData)
                    SizedBox(
                      width: 220,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _DayStat(
                            c: c,
                            value: _fmtHMS(day.totalActive),
                            label: 'Aktif',
                            valueColor: c.success,
                          ),
                          const SizedBox(width: 16),
                          _DayStat(
                            c: c,
                            value: '${day.totalScreenshots}',
                            label: 'Shot',
                          ),
                          const SizedBox(width: 16),
                          _DayStat(
                            c: c,
                            value: '${day.totalRecordings}',
                            label: 'Rekam',
                          ),
                        ],
                      ),
                    ),

                  // Col 4: chevron (22px)
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 22,
                    child: hasData
                        ? AnimatedRotation(
                            turns: widget.expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: c.textSubtle,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expanded detail
        if (widget.expanded) _DayDetail(c: c, day: day),

        // Divider
        if (!widget.isLast) Divider(height: 1, thickness: 1, color: c.borderSoft),
      ],
    );
  }
}

// ─── App Stack ────────────────────────────────────────────────────────────────

class _AppStack extends StatelessWidget {
  final AppColors c;
  final List<AppUsageSummary> apps;

  const _AppStack({required this.c, required this.apps});

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();
    const avatarSize = 22.0;
    const overlap = 5.0;

    return Row(
      children: [
        // Avatar stack
        SizedBox(
          width: apps.length * (avatarSize - overlap) + overlap,
          height: avatarSize,
          child: Stack(
            children: List.generate(apps.length, (i) {
              final app = apps[i];
              final color = _colorFor(app.appName);
              return Positioned(
                left: i * (avatarSize - overlap),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initialFor(app.appName),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        // App name list
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: apps.take(3).map((app) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      app.appName,
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _fmtHMS(app.duration),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: c.textSubtle,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Day Stat ─────────────────────────────────────────────────────────────────

class _DayStat extends StatelessWidget {
  final AppColors c;
  final String value;
  final String label;
  final Color? valueColor;

  const _DayStat({
    required this.c,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: valueColor ?? c.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.05,
            color: c.textSubtle,
          ),
        ),
      ],
    );
  }
}

// ─── Day Detail (expanded) ────────────────────────────────────────────────────

class _DayDetail extends StatelessWidget {
  final AppColors c;
  final HistoryDay day;

  const _DayDetail({required this.c, required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.bgSubtle,
      padding: const EdgeInsets.only(left: 138, right: 16, top: 12, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: timeline + top apps
          Expanded(
            flex: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SessionTimeline(c: c, day: day),
                const SizedBox(height: 12),
                if (day.topApps.isNotEmpty) ...[
                  Text(
                    'APP TERATAS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.06,
                      color: c.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...day.topApps.take(5).map((app) => _TopAppRow(c: c, app: app)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right column: recordings + screenshots + actions
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecordingsList(c: c, day: day),
                const SizedBox(height: 12),
                _ScreenshotTile(c: c, day: day),
                const SizedBox(height: 12),
                _ActionButtons(c: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session Timeline ─────────────────────────────────────────────────────────

class _SessionTimeline extends StatelessWidget {
  final AppColors c;
  final HistoryDay day;

  const _SessionTimeline({required this.c, required this.day});

  @override
  Widget build(BuildContext context) {
    const spanStart = 6; // 06:00
    const spanEnd = 18; // 18:00
    const spanHours = spanEnd - spanStart;
    final now = DateTime.now();
    final isToday = day.date.year == now.year &&
        day.date.month == now.month &&
        day.date.day == now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIMELINE SESI',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.06,
            color: c.textSubtle,
          ),
        ),
        const SizedBox(height: 6),
        // Visual bar
        LayoutBuilder(builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return Column(
            children: [
              Container(
                height: 20,
                width: barWidth,
                decoration: BoxDecoration(
                  color: c.bgMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    ...day.sessions.map((session) {
                      final startH = session.startTime.hour + session.startTime.minute / 60.0;
                      final endH = session.endTime.hour + session.endTime.minute / 60.0;
                      final left = ((startH - spanStart) / spanHours).clamp(0.0, 1.0) * barWidth;
                      final right = ((endH - spanStart) / spanHours).clamp(0.0, 1.0) * barWidth;
                      final width = (right - left).clamp(2.0, barWidth);
                      final isLive = isToday && session.endTime.isAfter(now.subtract(const Duration(minutes: 5)));
                      return Positioned(
                        left: left,
                        top: 2,
                        bottom: 2,
                        width: width,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isLive
                                ? c.danger.withValues(alpha: 0.8)
                                : c.accent.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Time labels
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['06:00', '09:00', '12:00', '15:00', '18:00'].map((t) {
                    return Text(
                      t,
                      style: TextStyle(fontSize: 9, color: c.textFaint, fontFamily: 'monospace'),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        // Session list rows
        ...day.sessions.map((session) => _SessionRow(c: c, session: session)),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final AppColors c;
  final HistorySession session;

  const _SessionRow({required this.c, required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6, top: 1),
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
          ),
          Text(
            '${_fmtTime(session.startTime)} – ${_fmtTime(session.endTime)}',
            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.textMuted),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtHMS(session.activeDuration),
            style: TextStyle(fontSize: 11, color: c.success),
          ),
        ],
      ),
    );
  }
}

class _TopAppRow extends StatelessWidget {
  final AppColors c;
  final AppUsageSummary app;

  const _TopAppRow({required this.c, required this.app});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(app.appName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initialFor(app.appName),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              app.appName,
              style: TextStyle(fontSize: 12, color: c.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _fmtHMS(app.duration),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: c.textSubtle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recordings List ──────────────────────────────────────────────────────────

class _RecordingsList extends StatelessWidget {
  final AppColors c;
  final HistoryDay day;

  const _RecordingsList({required this.c, required this.day});

  @override
  Widget build(BuildContext context) {
    final recordings = day.allRecordings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REKAMAN',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.06,
            color: c.textSubtle,
          ),
        ),
        const SizedBox(height: 6),
        if (recordings.isEmpty)
          Text(
            'Tidak ada rekaman',
            style: TextStyle(fontSize: 12, color: c.textFaint, fontStyle: FontStyle.italic),
          )
        else
          ...recordings.take(5).map((path) {
            final file = File(path);
            final name = path.split(Platform.pathSeparator).last;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.videocam_outlined, size: 13, color: c.textSubtle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: c.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (file.existsSync())
                    FutureBuilder<int>(
                      future: file.length(),
                      builder: (_, snap) {
                        if (!snap.hasData) return const SizedBox.shrink();
                        final kb = (snap.data! / 1024).toStringAsFixed(0);
                        return Text(
                          '${kb}KB',
                          style: TextStyle(fontSize: 10, color: c.textSubtle),
                        );
                      },
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ─── Screenshot Tile ──────────────────────────────────────────────────────────

class _ScreenshotTile extends StatelessWidget {
  final AppColors c;
  final HistoryDay day;

  const _ScreenshotTile({required this.c, required this.day});

  @override
  Widget build(BuildContext context) {
    final count = day.totalScreenshots;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, size: 13, color: c.textSubtle),
              const SizedBox(width: 5),
              Text(
                'Screenshot',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 3×2 placeholder grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 16 / 9,
            ),
            itemCount: 6,
            itemBuilder: (_, i) => Container(
              decoration: BoxDecoration(
                color: c.bgMuted,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.image_outlined, size: 14, color: c.textFaint),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {},
            child: Text(
              'Lihat semua →',
              style: TextStyle(
                fontSize: 11,
                color: c.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final AppColors c;

  const _ActionButtons({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(
          c: c,
          icon: Icons.download_outlined,
          label: 'Ekspor',
          onTap: () {},
        ),
        const SizedBox(width: 6),
        _ActionBtn(
          c: c,
          icon: Icons.folder_open_outlined,
          label: 'Buka folder',
          onTap: () {},
        ),
        const SizedBox(width: 6),
        _ActionBtn(
          c: c,
          icon: Icons.delete_outline,
          label: 'Hapus data',
          onTap: () {},
          danger: true,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ActionBtn({
    required this.c,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? c.danger : c.textMuted;
    final bg = danger ? c.dangerSoft : c.bgMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: danger ? c.danger.withValues(alpha: 0.3) : c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: fg)),
          ],
        ),
      ),
    );
  }
}

// ─── Info Banner ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final AppColors c;

  const _InfoBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.accentSoft,
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Anda aman — disimpan secara lokal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Semua data riwayat aktivitas disimpan hanya di perangkat ini menggunakan Hive. Tidak ada data yang dikirim ke server eksternal.',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
