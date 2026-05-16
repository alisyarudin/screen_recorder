// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/di.dart';
import '../../data/models/activity_entry.dart';
import '../blocs/monitoring/monitoring_cubit.dart';
import '../blocs/recording/recording_bloc.dart';
import '../widgets/app_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        _DashboardHeader(c: c, onTabChange: (i) => setState(() => _tabIndex = i), tabIndex: _tabIndex),
        Divider(height: 1, thickness: 1, color: c.borderSoft),
        _StatusPanel(c: c),
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _AppUsageTab(c: c),
              _ScreenshotTab(c: c),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Dashboard header ─────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final AppColors c;
  final int tabIndex;
  final ValueChanged<int> onTabChange;

  const _DashboardHeader({
    required this.c,
    required this.tabIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.bg,
      child: Column(
        children: [
          // Title row
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Dashboard Monitoring',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                          letterSpacing: -0.01 * 15,
                        ),
                      ),
                      Text(
                        'Pantau aktivitas dan penggunaan aplikasi',
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Monitor Aktif badge
                  BlocBuilder<MonitoringCubit, MonitoringState>(
                    builder: (context, state) {
                      if (!state.isMonitoring) return const SizedBox.shrink();
                      return Container(
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: c.successSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Monitor Aktif',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.success,
                          ),
                        ),
                      );
                    },
                  ),
                  const _MonitorToggleButton(),
                ],
              ),
            ),
          ),

          // Tab strip
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.borderSoft)),
            ),
            child: Row(
              children: [
                _TabBtn(
                  label: 'Penggunaan App',
                  active: tabIndex == 0,
                  c: c,
                  onTap: () => onTabChange(0),
                ),
                const SizedBox(width: 4),
                _TabBtn(
                  label: 'Screenshot',
                  active: tabIndex == 1,
                  c: c,
                  onTap: () => onTabChange(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final AppColors c;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? c.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            color: active ? c.accent : c.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Monitor toggle button ────────────────────────────────────────────────────

class _MonitorToggleButton extends StatefulWidget {
  const _MonitorToggleButton();

  @override
  State<_MonitorToggleButton> createState() => _MonitorToggleButtonState();
}

class _MonitorToggleButtonState extends State<_MonitorToggleButton> {
  bool _checking = false;

  Future<void> _requestStop() async {
    setState(() => _checking = true);
    final needsPassword = await DI.adminService.hasAdminPassword();
    setState(() => _checking = false);

    if (!needsPassword) {
      context.read<MonitoringCubit>().stopMonitoring();
      return;
    }

    final verified = await _showPasswordDialog();
    if (verified) context.read<MonitoringCubit>().stopMonitoring();
  }

  Future<bool> _showPasswordDialog() {
    return showPasswordDialog(
      context,
      title: 'Password diperlukan',
      subtitle: 'Masukkan password admin untuk menghentikan monitoring.',
      confirmLabel: 'Stop Monitoring',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        if (state.isMonitoring) {
          return InkWell(
            onTap: _checking ? null : _requestStop,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.danger,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_checking)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.stop_circle_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text(
                    'Berhenti Monitor',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => context.read<MonitoringCubit>().startMonitoring(),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monitor_heart_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                const Text(
                  'Mulai Monitor',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Status panel ─────────────────────────────────────────────────────────────

class _StatusPanel extends StatelessWidget {
  final AppColors c;

  const _StatusPanel({required this.c});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.bgSubtle,
            border: Border(bottom: BorderSide(color: c.borderSoft)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status row
              Row(
                children: [
                  _StatusBadge(
                    label: state.isMonitoring
                        ? (state.isIdle ? 'IDLE' : 'AKTIF')
                        : 'OFFLINE',
                    color: state.isMonitoring
                        ? (state.isIdle ? c.warning : c.success)
                        : c.textSubtle,
                    softColor: state.isMonitoring
                        ? (state.isIdle ? c.warningSoft : c.successSoft)
                        : c.bgMuted,
                  ),
                  const SizedBox(width: 10),
                  if (state.currentApp.isNotEmpty) ...[
                    Icon(Icons.desktop_windows_outlined, size: 13, color: c.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.currentApp,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'Belum ada aktivitas',
                        style: TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                    ),
                  BlocBuilder<RecordingBloc, RecordingState>(
                    builder: (_, rs) => rs is RecordingActive
                        ? Container(
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(
                              color: c.dangerSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record, size: 7, color: c.danger),
                                const SizedBox(width: 4),
                                Text(
                                  'REC',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: c.danger,
                                    letterSpacing: 0.05,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stat tiles
              Row(
                children: [
                  _StatTile(
                    c: c,
                    label: 'SESI',
                    value: _fmt(state.sessionDuration),
                    sublabel: 'total waktu',
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    c: c,
                    label: 'AKTIF',
                    value: _fmt(state.totalActiveDuration),
                    sublabel: 'produktif',
                    valueColor: c.success,
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    c: c,
                    label: 'IDLE',
                    value: _fmt(state.totalIdleDuration),
                    sublabel: 'tidak aktif',
                    valueColor: c.warning,
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    c: c,
                    label: 'SCREENSHOT',
                    value: '${state.screenshots.length}',
                    sublabel: 'diambil',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Screenshot interval
              Row(
                children: [
                  Text(
                    'Screenshot tiap:',
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                  const SizedBox(width: 8),
                  _IntervalChip(label: 'Off', seconds: 0, c: c),
                  _IntervalChip(label: '30 detik', seconds: 30, c: c),
                  _IntervalChip(label: '1 menit', seconds: 60, c: c),
                  _IntervalChip(label: '2 menit', seconds: 120, c: c),
                  _IntervalChip(label: '5 menit', seconds: 300, c: c),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color softColor;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.softColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final AppColors c;
  final String label;
  final String value;
  final String sublabel;
  final Color? valueColor;

  const _StatTile({
    required this.c,
    required this.label,
    required this.value,
    required this.sublabel,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.textSubtle,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: valueColor ?? c.text,
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

class _IntervalChip extends StatelessWidget {
  final String label;
  final int seconds;
  final AppColors c;

  const _IntervalChip({required this.label, required this.seconds, required this.c});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        final selected = state.screenshotInterval == seconds;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () => context.read<MonitoringCubit>().setScreenshotInterval(seconds),
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected ? c.accent : c.bgMuted,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected ? c.accent : c.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : c.textMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Tab 1: App usage ─────────────────────────────────────────────────────────

class _AppUsageTab extends StatefulWidget {
  final AppColors c;

  const _AppUsageTab({required this.c});

  @override
  State<_AppUsageTab> createState() => _AppUsageTabState();
}

class _AppUsageTabState extends State<_AppUsageTab> {
  String _sort = 'duration';

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        final summary = state.appUsageSummary;
        if (summary.isEmpty) {
          return _EmptyHint(
            c: c,
            icon: Icons.desktop_windows_outlined,
            message: 'Belum ada data penggunaan app.',
            hint: 'Mulai monitoring untuk melacak app yang digunakan agen.',
          );
        }

        final totalSecs = state.sessionDuration.inSeconds;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: app usage list
            Expanded(
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.borderSoft)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${summary.length} aplikasi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        const Spacer(),
                        _SegmentedMini(
                          c: c,
                          options: const [('duration', 'Durasi'), ('freq', 'Frekuensi')],
                          selected: _sort,
                          onSelect: (v) => setState(() => _sort = v),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(8),
                        color: c.bg,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.builder(
                        itemCount: summary.length,
                        itemBuilder: (context, i) {
                          final e = summary[i];
                          final pct = totalSecs > 0
                              ? (e.value.inSeconds / totalSecs).clamp(0.0, 1.0)
                              : 0.0;
                          final initial = e.key.isNotEmpty
                              ? e.key[0].toUpperCase()
                              : '?';
                          final appColor = _appColor(e.key, c);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: i < summary.length - 1
                                    ? BorderSide(color: c.borderSoft)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: appColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: appColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e.key,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: c.text,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            _fmtDuration(e.value),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                              color: c.textMuted,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          minHeight: 4,
                                          backgroundColor: c.bgMuted,
                                          valueColor: AlwaysStoppedAnimation(appColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right: activity log
            Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c.borderSoft)),
              ),
              child: Column(
                children: [
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.borderSoft)),
                    ),
                    child: Text(
                      'Log Aktivitas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.appLog.length,
                      itemBuilder: (context, i) {
                        final e = state.appLog.reversed.toList()[i];
                        return _AppLogRow(c: c, entry: e);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _appColor(String name, AppColors c) {
    final colors = [c.accent, c.success, c.warning, c.danger];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _SegmentedMini extends StatelessWidget {
  final AppColors c;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentedMini({
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
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt.$1 == selected;
          return GestureDetector(
            onTap: () => onSelect(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? c.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                opt.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? c.text : c.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AppLogRow extends StatelessWidget {
  final AppColors c;
  final AppUsageEntry entry;

  const _AppLogRow({required this.c, required this.entry});

  @override
  Widget build(BuildContext context) {
    final start = _fmtTime(entry.startTime);
    final end = entry.endTime != null ? _fmtTime(entry.endTime!) : 'sekarang';
    final dur = entry.duration;
    final durStr = '${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.appName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$durStr · $start – $end',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

// ─── Tab 2: Screenshots ───────────────────────────────────────────────────────

class _ScreenshotTab extends StatefulWidget {
  final AppColors c;

  const _ScreenshotTab({required this.c});

  @override
  State<_ScreenshotTab> createState() => _ScreenshotTabState();
}

class _ScreenshotTabState extends State<_ScreenshotTab> {
  String _view = 'grid';

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        if (state.screenshots.isEmpty) {
          return _EmptyHint(
            c: c,
            icon: Icons.photo_camera_outlined,
            message: 'Belum ada screenshot.',
            hint: 'Aktifkan monitoring dan pilih interval screenshot di atas.',
          );
        }

        return Column(
          children: [
            // Header
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.borderSoft)),
              ),
              child: Row(
                children: [
                  Text(
                    '${state.screenshots.length} screenshot',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _screenshotDir(state),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: c.textSubtle,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SegmentedMini(
                    c: c,
                    options: const [('grid', 'Grid'), ('list', 'List')],
                    selected: _view,
                    onSelect: (v) => setState(() => _view = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _view == 'grid'
                  ? GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: state.screenshots.length,
                      itemBuilder: (context, i) =>
                          _ScreenshotTile(entry: state.screenshots[i], c: c),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.screenshots.length,
                      itemBuilder: (context, i) => _ScreenshotListRow(
                        entry: state.screenshots[i],
                        c: c,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _screenshotDir(MonitoringState state) {
    if (state.screenshots.isEmpty) return '';
    return File(state.screenshots.first.path).parent.path;
  }
}

class _ScreenshotTile extends StatelessWidget {
  final ScreenshotEntry entry;
  final AppColors c;

  const _ScreenshotTile({required this.entry, required this.c});

  @override
  Widget build(BuildContext context) {
    final file = File(entry.path);
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : Container(
                    color: c.bgMuted,
                    child: Icon(Icons.broken_image_outlined, color: c.textFaint, size: 28),
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.appName.isNotEmpty)
                      Text(
                        entry.appName,
                        style: const TextStyle(color: Colors.white70, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    showScreenshotFullscreen(context, entry);
  }
}

class _ScreenshotListRow extends StatelessWidget {
  final ScreenshotEntry entry;
  final AppColors c;

  const _ScreenshotListRow({required this.entry, required this.c});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(7),
        color: c.bg,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 60,
              height: 34,
              child: File(entry.path).existsSync()
                  ? Image.file(File(entry.path), fit: BoxFit.cover)
                  : Container(
                      color: c.bgMuted,
                      child: Icon(Icons.broken_image_outlined, size: 16, color: c.textFaint),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.appName.isEmpty ? 'Screenshot' : entry.appName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.textMuted),
                ),
              ],
            ),
          ),
          Text(
            entry.path.split('/').last,
            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.textSubtle),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Empty hint ───────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String message;
  final String hint;

  const _EmptyHint({
    required this.c,
    required this.icon,
    required this.message,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.bgMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c.textFaint, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: TextStyle(fontSize: 12, color: c.textSubtle),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
