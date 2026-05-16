import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/di.dart';
import '../../data/models/history_entry.dart';
import '../blocs/history/history_cubit.dart';

// ─── App colour palette ───────────────────────────────────────────────────────

const _kAppColors = {
  'Google Chrome':       Color(0xFF4285F4),
  'Microsoft Teams':     Color(0xFF6264A7),
  'Visual Studio Code':  Color(0xFF0078D4),
  'Slack':               Color(0xFF611F69),
  'Notepad':             Color(0xFFFFB900),
  'Microsoft Outlook':   Color(0xFF0078D4),
  'Spotify':             Color(0xFF1DB954),
  'Figma':               Color(0xFFA259FF),
  'Postman':             Color(0xFFFF6C37),
};

Color _colorFor(String n) => _kAppColors[n] ?? const Color(0xFF8B8B9E);
String _initialFor(String n) => n.isNotEmpty ? n[0].toUpperCase() : '?';

// ─── Format helpers ───────────────────────────────────────────────────────────

String _fmtHHMM(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$h:$m';
}

String _fmtIdleShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$h:$m';
}

const _kDayNames  = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _kMonthFull = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];
const _kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final d   = DateTime(date.year, date.month, date.day);
  final t   = DateTime(now.year,  now.month,  now.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return '${_kDayNames[date.weekday - 1]}, ${date.day} ${_kMonthShort[date.month - 1]}';
}

String _fullDateLabel(DateTime d) =>
    '${d.day} ${_kMonthFull[d.month - 1]} ${d.year}';

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

// ─── File / folder helpers ────────────────────────────────────────────────────

String _defaultOutputDir() {
  final sep  = Platform.isWindows ? '\\' : '/';
  final home = Platform.isWindows
      ? (Platform.environment['USERPROFILE'] ??
          '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}')
      : (Platform.environment['HOME'] ?? '/tmp');
  return '$home${sep}Jasnita Screen Recorder';
}

String _baseDir() {
  final s = DI.settingsService.load();
  return s.outputDir.isEmpty ? _defaultOutputDir() : s.outputDir;
}

String _dailyDirFor(DateTime d) {
  final sep   = Platform.pathSeparator;
  final year  = d.year.toString();
  final month = d.month.toString().padLeft(2, '0');
  final day   = d.day.toString().padLeft(2, '0');
  return '${_baseDir()}$sep$year$sep$month$sep$day';
}

// ─── Action helpers ───────────────────────────────────────────────────────────

void _showRecordingsDialog(BuildContext context, AppColors c, HistoryDay day) {
  showDialog(context: context, builder: (_) => _RecordingsDialog(c: c, day: day));
}

void _showScreenshotsDialog(BuildContext context, AppColors c, HistoryDay day) {
  showDialog(context: context, builder: (_) => _ScreenshotsDialog(c: c, day: day));
}

Future<void> _exportDayCsv(BuildContext context, HistoryDay day) async {
  final base  = _baseDir();
  final ts    = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fpath = '$base${Platform.pathSeparator}riwayat_${day.dateKey}_$ts.csv';
  final csv   = StringBuffer(
      'Tanggal,Aktif (menit),Idle (menit),Screenshot,Rekaman,Aplikasi\n');
  csv.write('"${_fullDateLabel(day.date)}",${day.totalActive.inMinutes}'
      ',${day.totalIdle.inMinutes},${day.totalScreenshots}'
      ',${day.totalRecordings},"${day.topApps.map((a) => a.appName).join('; ')}"\n');
  try {
    await Directory(base).create(recursive: true);
    await File(fpath).writeAsString(csv.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Disimpan: riwayat_${day.dateKey}_$ts.csv'),
        action: SnackBarAction(
            label: 'Buka Folder',
            onPressed: () => Process.run('open', [base])),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekspor: $e')));
    }
  }
}

Future<void> _openDayFolder(BuildContext context, HistoryDay day) async {
  final dir = _dailyDirFor(day.date);
  final target = await Directory(dir).exists() ? dir : _baseDir();
  await Process.run('open', [target]);
}

Future<void> _deleteDayData(
    BuildContext context, AppColors c, HistoryDay day) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.bg,
      title: Text('Hapus data ${_dayLabel(day.date)}?',
          style: TextStyle(color: c.text, fontSize: 14)),
      content: Text(
          'Data riwayat ${_fullDateLabel(day.date)} akan dihapus permanen.',
          style: TextStyle(color: c.textMuted, fontSize: 13)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: c.textMuted))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: c.danger))),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await DI.historyService.deleteDay(day.dateKey);
    if (context.mounted) context.read<HistoryCubit>().reload();
  }
}

// ─── History Screen ───────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _toDate   = DateTime(now.year, now.month, now.day);
    _fromDate = _toDate.subtract(const Duration(days: 15));
    context.read<HistoryCubit>().load();
  }

  List<HistoryDay> _filtered(List<HistoryDay> all) {
    return all.where((d) {
      final date = DateTime(d.date.year, d.date.month, d.date.day);
      return !date.isBefore(_fromDate) && !date.isAfter(_toDate);
    }).toList();
  }

  Future<void> _pickDate(bool isFrom) async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate.isAfter(picked)) _fromDate = picked;
      }
    });
  }

  Future<void> _exportAllCsv(List<HistoryDay> days) async {
    if (days.isEmpty) return;
    final base  = _baseDir();
    final ts    = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fpath = '$base${Platform.pathSeparator}riwayat_$ts.csv';
    final csv   = StringBuffer(
        'Tanggal,Aktif (menit),Idle (menit),Screenshot,Rekaman,Aplikasi\n');
    for (final d in days) {
      csv.write('"${_fullDateLabel(d.date)}",${d.totalActive.inMinutes}'
          ',${d.totalIdle.inMinutes},${d.totalScreenshots}'
          ',${d.totalRecordings},"${d.topApps.map((a) => a.appName).join('; ')}"\n');
    }
    try {
      await Directory(base).create(recursive: true);
      await File(fpath).writeAsString(csv.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Disimpan: riwayat_$ts.csv'),
          action: SnackBarAction(
              label: 'Buka Folder',
              onPressed: () => Process.run('open', [base])),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal ekspor: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        final filtered = _filtered(state.days);
        return Column(
          children: [
            _PageHeader(
              c: c,
              fromDate: _fromDate,
              toDate: _toDate,
              onPickFrom: () => _pickDate(true),
              onPickTo: () => _pickDate(false),
              onExportCsv: () => _exportAllCsv(filtered),
            ),
            Divider(height: 1, thickness: 1, color: c.borderSoft),
            Expanded(
              child: state.isLoading
                  ? Center(child: CircularProgressIndicator(color: c.accent))
                  : _HistoryBody(c: c, days: filtered),
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
  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onExportCsv;

  const _PageHeader({
    required this.c,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: c.text, letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Data aktivitas tersimpan per hari · klik baris hari untuk lihat detail',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _DateRangePicker(
            c: c,
            fromDate: fromDate,
            toDate: toDate,
            onPickFrom: onPickFrom,
            onPickTo: onPickTo,
          ),
          const SizedBox(width: 8),
          _SmallOutlineBtn(
            c: c,
            icon: Icons.download_outlined,
            label: 'Ekspor CSV',
            onTap: onExportCsv,
          ),
        ],
      ),
    );
  }
}

// ─── Date Range Picker ────────────────────────────────────────────────────────

class _DateRangePicker extends StatelessWidget {
  final AppColors c;
  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  const _DateRangePicker({
    required this.c,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final days      = toDate.difference(fromDate).inDays + 1;
    final fromLabel = '${fromDate.day} ${_kMonthShort[fromDate.month - 1]} ${fromDate.year}';
    final toLabel   = '${toDate.day} ${_kMonthShort[toDate.month - 1]} ${toDate.year}';

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateField(c: c, label: 'DARI',   value: fromLabel, onTap: onPickFrom),
            VerticalDivider(width: 1, thickness: 1, color: c.borderSoft),
            _DateField(c: c, label: 'SAMPAI', value: toLabel,   onTap: onPickTo),
            VerticalDivider(width: 1, thickness: 1, color: c.borderSoft),
            Container(
              color: c.bgSubtle,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$days hari',
                    style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: c.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  final AppColors c;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateField({required this.c, required this.label, required this.value, required this.onTap});

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _hover ? c.bgHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10, color: c.textSubtle,
                  letterSpacing: 0.06, fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── History Body ─────────────────────────────────────────────────────────────

class _HistoryBody extends StatelessWidget {
  final AppColors c;
  final List<HistoryDay> days;
  const _HistoryBody({required this.c, required this.days});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        if (days.isEmpty)
          _EmptyState(c: c)
        else
          _DayListCard(c: c, days: days),
        const SizedBox(height: 14),
        _InfoBanner(c: c),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 32, color: c.textFaint),
          const SizedBox(height: 10),
          Text(
            'Belum ada riwayat aktivitas',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: c.textSubtle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mulai monitoring untuk merekam aktivitas harian',
            style: TextStyle(fontSize: 12, color: c.textFaint),
          ),
        ],
      ),
    );
  }
}

// ─── Day List Card ────────────────────────────────────────────────────────────

class _DayListCard extends StatefulWidget {
  final AppColors c;
  final List<HistoryDay> days;
  const _DayListCard({required this.c, required this.days});

  @override
  State<_DayListCard> createState() => _DayListCardState();
}

class _DayListCardState extends State<_DayListCard> {
  int  _expandedIdx = 0; // today expanded by default
  bool _showAll     = false;

  @override
  Widget build(BuildContext context) {
    final c      = widget.c;
    final days   = widget.days;
    final count  = _showAll ? days.length : days.length.clamp(0, 14);
    final visible = days.take(count).toList();
    final hasMore = days.length > 14 && !_showAll;

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...List.generate(visible.length, (i) => _DayCard(
            c: c,
            day: visible[i],
            expanded: _expandedIdx == i,
            onToggle: visible[i].sessions.isNotEmpty
                ? () => setState(() => _expandedIdx = _expandedIdx == i ? -1 : i)
                : null,
            showTopBorder: i > 0,
          )),
          if (hasMore) _ShowMoreRow(c: c, onTap: () => setState(() => _showAll = true)),
        ],
      ),
    );
  }
}

class _ShowMoreRow extends StatefulWidget {
  final AppColors c;
  final VoidCallback onTap;
  const _ShowMoreRow({required this.c, required this.onTap});

  @override
  State<_ShowMoreRow> createState() => _ShowMoreRowState();
}

class _ShowMoreRowState extends State<_ShowMoreRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? c.bgHover : c.bgSubtle,
            border: Border(top: BorderSide(color: c.borderSoft)),
          ),
          child: Center(
            child: Text(
              'Tampilkan riwayat lebih lama',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
          ),
        ),
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
  final bool showTopBorder;

  const _DayCard({
    required this.c,
    required this.day,
    required this.expanded,
    required this.onToggle,
    required this.showTopBorder,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c       = widget.c;
    final day     = widget.day;
    final hasData = day.sessions.isNotEmpty;
    final today   = _isToday(day.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top separator
        if (widget.showTopBorder)
          Divider(height: 1, thickness: 1, color: c.borderSoft),

        // Row
        MouseRegion(
          cursor: hasData ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: hasData ? (_) => setState(() => _hovered = true)  : null,
          onExit:  hasData ? (_) => setState(() => _hovered = false) : null,
          child: GestureDetector(
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              color: _hovered && hasData
                  ? c.bgHover
                  : widget.expanded ? c.bgSubtle : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  // Date (130px)
                  SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _dayLabel(day.date),
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: hasData ? c.text : c.textSubtle,
                                ),
                              ),
                            ),
                            if (today) ...[
                              const SizedBox(width: 6),
                              _LiveBadge(c: c),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fullDateLabel(day.date),
                          style: TextStyle(fontSize: 11, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),

                  // App stack
                  Expanded(
                    child: hasData
                        ? _AppStack(c: c, apps: day.topApps.take(6).toList())
                        : Text(
                            'Tidak ada aktivitas — monitor tidak dijalankan',
                            style: TextStyle(
                              fontSize: 12, color: c.textSubtle,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),

                  // Stats: Aktif | Idle | Shot | Rekam
                  if (hasData) ...[
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        _DayStat(c: c, label: 'Aktif', value: _fmtHHMM(day.totalActive),  accent: c.success),
                        const SizedBox(width: 16),
                        _DayStat(c: c, label: 'Idle',  value: _fmtIdleShort(day.totalIdle)),
                        const SizedBox(width: 16),
                        _DayStat(c: c, label: 'Shot',  value: '${day.totalScreenshots}'),
                        const SizedBox(width: 16),
                        _DayStat(c: c, label: 'Rekam', value: '${day.totalRecordings}'),
                      ],
                    ),
                  ],

                  // Chevron
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 22, height: 22,
                    child: hasData
                        ? AnimatedRotation(
                            turns: widget.expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(Icons.chevron_right, size: 16, color: c.textSubtle),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expanded detail
        if (widget.expanded && hasData) _DayDetail(c: c, day: day),
      ],
    );
  }
}

// ─── Live Badge ───────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final AppColors c;
  const _LiveBadge({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Live',
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: c.accent, letterSpacing: 0.02,
        ),
      ),
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
    const size    = 22.0;
    const overlap = 5.0;

    final shown = apps.take(4).toList();
    final extra = apps.length - shown.length;
    final totalChips = shown.length + (extra > 0 ? 1 : 0);
    final stackWidth = totalChips * (size - overlap) + overlap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: size,
          child: Stack(
            children: [
              ...List.generate(shown.length, (i) {
                final color = _colorFor(shown[i].appName);
                return Positioned(
                  left: i * (size - overlap),
                  child: Container(
                    width: size, height: size,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: c.bgSubtle, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initialFor(shown[i].appName),
                      style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
              if (extra > 0)
                Positioned(
                  left: shown.length * (size - overlap),
                  child: Container(
                    width: size, height: size,
                    decoration: BoxDecoration(
                      color: c.bgMuted,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: c.bgSubtle, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$extra',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${apps.length} aplikasi',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

// ─── Day Stat ─────────────────────────────────────────────────────────────────

class _DayStat extends StatelessWidget {
  final AppColors c;
  final String label;
  final String value;
  final Color? accent;
  const _DayStat({required this.c, required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
            color: accent ?? c.text,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10, letterSpacing: 0.04, color: c.textSubtle,
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
    final apps      = day.topApps;
    final totalSec  = day.totalActive.inSeconds;
    final isToday   = _isToday(day.date);

    return Container(
      color: c.bgSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, thickness: 1, color: c.borderSoft),
          Padding(
            padding: const EdgeInsets.fromLTRB(138, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Apps used ────────────────────────────────────────
                if (apps.isNotEmpty) ...[
                  Text(
                    'Aplikasi yang dibuka (${apps.length})',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      letterSpacing: 0.03, color: c.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: c.bg,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: List.generate(apps.length, (i) {
                        final pct = totalSec > 0
                            ? (apps[i].duration.inSeconds / totalSec).clamp(0.0, 1.0)
                            : 0.0;
                        return _DetailAppRow(
                          c: c, app: apps[i], pct: pct, isFirst: i == 0,
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Rekaman + Screenshot links ────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _DetailLink(
                        c: c,
                        icon: Icons.videocam_outlined,
                        label: 'Rekaman',
                        value: '${day.totalRecordings} file',
                        sub: 'Klik untuk lihat daftar',
                        onTap: () => _showRecordingsDialog(context, c, day),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DetailLink(
                        c: c,
                        icon: Icons.photo_camera_outlined,
                        label: 'Screenshot',
                        value: '${day.totalScreenshots} gambar',
                        sub: 'Klik untuk lihat semua',
                        onTap: () => _showScreenshotsDialog(context, c, day),
                      ),
                    ),
                  ],
                ),

                // ── Footer actions ────────────────────────────────────
                const SizedBox(height: 14),
                Row(
                  children: [
                    _SmallBtn(
                      c: c, icon: Icons.download_outlined,
                      label: 'Ekspor hari ini',
                      onTap: () => _exportDayCsv(context, day),
                    ),
                    const SizedBox(width: 8),
                    _SmallBtn(
                      c: c, icon: Icons.folder_open_outlined,
                      label: 'Buka folder',
                      onTap: () => _openDayFolder(context, day),
                    ),
                    const Spacer(),
                    if (!isToday)
                      _SmallBtn(
                        c: c, icon: Icons.delete_outline,
                        label: 'Hapus data hari ini',
                        onTap: () { _deleteDayData(context, c, day); },
                        danger: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail App Row ───────────────────────────────────────────────────────────

class _DetailAppRow extends StatelessWidget {
  final AppColors c;
  final AppUsageSummary app;
  final double pct; // 0.0–1.0
  final bool isFirst;

  const _DetailAppRow({
    required this.c, required this.app, required this.pct, required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(app.appName);
    return Container(
      decoration: isFirst
          ? null
          : BoxDecoration(border: Border(top: BorderSide(color: c.borderSoft))),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          // Square avatar
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Text(
              _initialFor(app.appName),
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  app.appName,
                  style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w500, color: c.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: c.bgMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Duration
          Text(
            _fmtHHMM(app.duration),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: c.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Link ──────────────────────────────────────────────────────────────

class _DetailLink extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  const _DetailLink({
    required this.c, required this.icon, required this.label,
    required this.value, required this.sub, required this.onTap,
  });

  @override
  State<_DetailLink> createState() => _DetailLinkState();
}

class _DetailLinkState extends State<_DetailLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _hover ? c.bgHover : c.bg,
            border: Border.all(color: _hover ? c.borderStrong : c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(widget.icon, size: 15, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500, color: c.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.value,
                          style: TextStyle(
                            fontSize: 12, fontFamily: 'monospace', color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.sub,
                      style: TextStyle(fontSize: 11, color: c.textSubtle),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: c.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small Buttons ────────────────────────────────────────────────────────────

class _SmallBtn extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SmallBtn({
    required this.c, required this.icon, required this.label,
    required this.onTap, this.danger = false,
  });

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c  = widget.c;
    final fg = widget.danger ? c.danger : c.textMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover
                ? (widget.danger ? c.dangerSoft : c.bgMuted)
                : Colors.transparent,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(widget.label, style: TextStyle(fontSize: 11, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallOutlineBtn extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallOutlineBtn({
    required this.c, required this.icon, required this.label, required this.onTap,
  });

  @override
  State<_SmallOutlineBtn> createState() => _SmallOutlineBtnState();
}

class _SmallOutlineBtnState extends State<_SmallOutlineBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover ? c.bgMuted : c.bg,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: c.textMuted),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(fontSize: 12, color: c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recordings Dialog ────────────────────────────────────────────────────────

class _RecordingsDialog extends StatelessWidget {
  final AppColors c;
  final HistoryDay day;
  const _RecordingsDialog({required this.c, required this.day});

  @override
  Widget build(BuildContext context) {
    final files = day.allRecordings;
    return Dialog(
      backgroundColor: c.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Text('Rekaman — ${_dayLabel(day.date)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 16, color: c.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: c.borderSoft),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Tidak ada file rekaman',
                    style: TextStyle(color: c.textMuted, fontSize: 13))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _RecordingFileRow(c: c, path: files[i]),
                ),
              ),
            Divider(height: 1, color: c.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Text('${files.length} file',
                      style: TextStyle(fontSize: 12, color: c.textSubtle)),
                  const Spacer(),
                  _SmallBtn(
                    c: c, icon: Icons.folder_open_outlined, label: 'Buka folder',
                    onTap: () => _openDayFolder(context, day),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingFileRow extends StatefulWidget {
  final AppColors c;
  final String path;
  const _RecordingFileRow({required this.c, required this.path});

  @override
  State<_RecordingFileRow> createState() => _RecordingFileRowState();
}

class _RecordingFileRowState extends State<_RecordingFileRow> {
  bool _hover = false;
  int? _sizeBytes;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    try {
      final f = File(widget.path);
      if (await f.exists()) {
        final s = await f.length();
        if (mounted) setState(() => _sizeBytes = s);
      }
    } catch (_) {}
  }

  String get _name => widget.path.split(Platform.pathSeparator).last;

  String get _sizeStr {
    final s = _sizeBytes;
    if (s == null) return '…';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(0)} KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Process.run('open', [widget.path]),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: _hover ? c.bgHover : c.bgSubtle,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.videocam_outlined, size: 14, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_name,
                    style: TextStyle(fontSize: 12, color: c.text),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(_sizeStr,
                  style: TextStyle(
                      fontSize: 11, color: c.textMuted, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 12, color: c.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Screenshots Dialog ───────────────────────────────────────────────────────

class _ScreenshotsDialog extends StatefulWidget {
  final AppColors c;
  final HistoryDay day;
  const _ScreenshotsDialog({required this.c, required this.day});

  @override
  State<_ScreenshotsDialog> createState() => _ScreenshotsDialogState();
}

class _ScreenshotsDialogState extends State<_ScreenshotsDialog> {
  List<String> _paths = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final d     = widget.day.date;
    final year  = d.year.toString();
    final month = d.month.toString().padLeft(2, '0');
    final day   = d.day.toString().padLeft(2, '0');
    final sep   = Platform.pathSeparator;
    final base  = _baseDir();
    final paths = <String>[];

    // New year/month/day structure
    final newDir = Directory('$base$sep$year$sep$month$sep$day');
    if (await newDir.exists()) {
      await for (final f in newDir.list()) {
        final name = f.path.split(sep).last;
        if (f is File && name.startsWith('SCR_') && name.endsWith('.jpg')) {
          paths.add(f.path);
        }
      }
    }

    // Legacy Screenshots folder
    final dateStr  = '$year$month$day';
    final legacyDir = Directory('$base${sep}Screenshots');
    if (await legacyDir.exists()) {
      await for (final f in legacyDir.list()) {
        final name = f.path.split(sep).last;
        if (f is File && name.startsWith('SCR_$dateStr') && name.endsWith('.jpg')) {
          paths.add(f.path);
        }
      }
    }

    paths.sort();
    if (mounted) setState(() { _paths = paths; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Dialog(
      backgroundColor: c.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Text('Screenshot — ${_dayLabel(widget.day.date)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 16, color: c.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: c.borderSoft),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_paths.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Tidak ada file screenshot',
                    style: TextStyle(color: c.textMuted, fontSize: 13))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: _paths.length,
                  itemBuilder: (_, i) => _ScreenshotThumbnail(
                    c: c, path: _paths[i], index: i, allPaths: _paths,
                  ),
                ),
              ),
            Divider(height: 1, color: c.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Text('${_paths.length} gambar',
                      style: TextStyle(fontSize: 12, color: c.textSubtle)),
                  const Spacer(),
                  _SmallBtn(
                    c: c, icon: Icons.folder_open_outlined, label: 'Buka folder',
                    onTap: () => _openDayFolder(context, widget.day),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotThumbnail extends StatefulWidget {
  final AppColors c;
  final String path;
  final int index;
  final List<String> allPaths;
  const _ScreenshotThumbnail({
    required this.c, required this.path,
    required this.index, required this.allPaths,
  });

  @override
  State<_ScreenshotThumbnail> createState() => _ScreenshotThumbnailState();
}

class _ScreenshotThumbnailState extends State<_ScreenshotThumbnail> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => _ScreenshotFullscreenDialog(
            c: c, index: widget.index, allPaths: widget.allPaths,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hover ? c.accent : c.border,
              width: _hover ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(widget.path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: c.bgSubtle,
              child: Icon(Icons.broken_image_outlined, size: 24, color: c.textFaint),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotFullscreenDialog extends StatefulWidget {
  final AppColors c;
  final int index;
  final List<String> allPaths;
  const _ScreenshotFullscreenDialog({
    required this.c, required this.index, required this.allPaths,
  });

  @override
  State<_ScreenshotFullscreenDialog> createState() =>
      _ScreenshotFullscreenDialogState();
}

class _ScreenshotFullscreenDialogState
    extends State<_ScreenshotFullscreenDialog> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.index;
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.allPaths[_current];
    final name = path.split(Platform.pathSeparator).last;
    final total = widget.allPaths.length;

    return Dialog(
      backgroundColor: const Color(0xFF0A0A0A),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 960,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                        overflow: TextOverflow.ellipsis),
                  ),
                  TextButton.icon(
                    onPressed: () => Process.run('open', ['-R', path]),
                    icon: const Icon(Icons.folder_open_outlined, size: 13, color: Colors.white38),
                    label: const Text('Buka di Finder',
                        style: TextStyle(fontSize: 12, color: Colors.white38)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 280,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.white12),
                ),
              ),
            ),
            if (total > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _current > 0
                          ? () => setState(() => _current--)
                          : null,
                      icon: Icon(Icons.chevron_left,
                          color: _current > 0 ? Colors.white54 : Colors.white12),
                    ),
                    Text('${_current + 1} / $total',
                        style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    IconButton(
                      onPressed: _current < total - 1
                          ? () => setState(() => _current++)
                          : null,
                      icon: Icon(Icons.chevron_right,
                          color: _current < total - 1 ? Colors.white54 : Colors.white12),
                    ),
                  ],
                ),
              ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        border: Border.all(color: c.borderSoft),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 13, color: c.textSubtle),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Data tersimpan otomatis. Stop/start monitor tidak menghapus data — '
              'sesi baru ditambahkan ke hari berjalan.',
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Text(
              'Pengaturan retensi →',
              style: TextStyle(
                fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
