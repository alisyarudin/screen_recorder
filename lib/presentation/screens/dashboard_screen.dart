// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/di.dart';
import '../../data/models/activity_entry.dart';
import '../blocs/monitoring/monitoring_cubit.dart';
import '../blocs/recording/recording_bloc.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.panel,
          surfaceTintColor: Colors.transparent,
          title: Text('Dashboard Monitoring',
              style: TextStyle(color: c.text, fontSize: 15)),
          iconTheme: IconThemeData(color: c.textMuted),
          elevation: 0,
          actions: [
            const _MonitorToggleButton(),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              children: [
                Divider(height: 1, color: c.border),
                TabBar(
                  labelColor: c.primary,
                  unselectedLabelColor: c.textMuted,
                  indicatorColor: c.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Penggunaan App'),
                    Tab(text: 'Screenshot'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            const _StatusPanel(),
            Expanded(
              child: TabBarView(
                children: [
                  const _AppUsageTab(),
                  const _ScreenshotTab(),
                ],
              ),
            ),
          ],
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

  Future<bool> _showPasswordDialog() async {
    final ctrl = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Stop Monitoring'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan password admin untuk menghentikan monitoring.'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password Admin',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) async {
                  final ok = await DI.adminService.verifyAdminPassword(ctrl.text);
                  if (ok) {
                    Navigator.of(ctx).pop(true);
                  } else {
                    setLocal(() => errorText = 'Password salah');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await DI.adminService.verifyAdminPassword(ctrl.text);
                if (ok) {
                  Navigator.of(ctx).pop(true);
                } else {
                  setLocal(() => errorText = 'Password salah');
                }
              },
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        if (state.isMonitoring) {
          return FilledButton.icon(
            onPressed: _checking ? null : _requestStop,
            icon: _checking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.stop_circle_outlined, size: 16),
            label: const Text('Stop Monitor'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          );
        }
        return FilledButton.icon(
          onPressed: () => context.read<MonitoringCubit>().startMonitoring(),
          icon: const Icon(Icons.monitor_heart_outlined, size: 16),
          label: const Text('Mulai Monitor'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        );
      },
    );
  }
}

// ─── Status panel ─────────────────────────────────────────────────────────────

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: c.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris status utama
              Row(
                children: [
                  _StatusBadge(
                    label: state.isMonitoring
                        ? (state.isIdle ? 'IDLE' : 'AKTIF')
                        : 'OFFLINE',
                    color: state.isMonitoring
                        ? (state.isIdle ? AppColors.of(context).warn : AppColors.of(context).success)
                        : AppColors.of(context).textMuted,
                  ),
                  const SizedBox(width: 12),
                  if (state.currentApp.isNotEmpty) ...[
                    Icon(Icons.desktop_windows_outlined,
                        size: 14, color: c.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.currentApp,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text('Belum ada aktivitas',
                          style: TextStyle(color: c.textMuted, fontSize: 13)),
                    ),
                  // Recording indicator
                  BlocBuilder<RecordingBloc, RecordingState>(
                    builder: (_, rs) => rs is RecordingActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.dangerSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record,
                                    size: 8, color: c.danger),
                                const SizedBox(width: 4),
                                Text('REC',
                                    style: TextStyle(
                                        color: c.danger,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Kartu statistik
              Row(
                children: [
                  _StatCard(
                    c: c,
                    icon: Icons.timer_outlined,
                    label: 'Sesi',
                    value: _fmt(state.sessionDuration),
                    color: c.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    c: c,
                    icon: Icons.check_circle_outline,
                    label: 'Aktif',
                    value: _fmt(state.totalActiveDuration),
                    color: c.success,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    c: c,
                    icon: Icons.pause_circle_outline,
                    label: 'Idle',
                    value: _fmt(state.totalIdleDuration),
                    color: c.warn,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    c: c,
                    icon: Icons.photo_camera_outlined,
                    label: 'Screenshot',
                    value: '${state.screenshots.length}',
                    color: c.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Screenshot interval control
              Row(
                children: [
                  Text('Screenshot tiap:',
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                  const SizedBox(width: 8),
                  ...[
                    _IntervalChip(label: 'Off', seconds: 0),
                    _IntervalChip(label: '30d', seconds: 30),
                    _IntervalChip(label: '1m', seconds: 60),
                    _IntervalChip(label: '2m', seconds: 120),
                    _IntervalChip(label: '5m', seconds: 300),
                  ],
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
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.panelAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(color: c.textMuted, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final int seconds;
  const _IntervalChip({required this.label, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        final selected = state.screenshotInterval == seconds;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () =>
                context.read<MonitoringCubit>().setScreenshotInterval(seconds),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? c.primary : c.panelAlt,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected ? c.primary : c.border),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : c.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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

class _AppUsageTab extends StatelessWidget {
  const _AppUsageTab();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${summary.length} aplikasi digunakan',
              style: TextStyle(
                  color: c.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            ...summary.map((e) =>
                _AppUsageRow(c: c, entry: e, totalSecs: totalSecs)),
            const SizedBox(height: 16),
            // Log lengkap (timeline)
            Text(
              'LOG AKTIVITAS',
              style: TextStyle(
                  color: c.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            ...state.appLog.reversed.map((e) => _AppLogRow(c: c, entry: e)),
          ],
        );
      },
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  final AppColors c;
  final MapEntry<String, Duration> entry;
  final int totalSecs;
  const _AppUsageRow(
      {required this.c, required this.entry, required this.totalSecs});

  @override
  Widget build(BuildContext context) {
    final pct = totalSecs > 0
        ? entry.value.inSeconds / totalSecs
        : 0.0;
    final dur = _fmtDuration(entry.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.key,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(dur,
                  style: TextStyle(
                      color: c.textMuted,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation(c.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: c.primary),
          ),
          Expanded(
            child: Text(entry.appName,
                style: TextStyle(color: c.text, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          Text('$start – $end',
              style: TextStyle(color: c.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

// ─── Tab 2: Screenshots ───────────────────────────────────────────────────────

class _ScreenshotTab extends StatelessWidget {
  const _ScreenshotTab();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<MonitoringCubit, MonitoringState>(
      builder: (context, state) {
        if (state.screenshots.isEmpty) {
          return _EmptyHint(
            c: c,
            icon: Icons.photo_camera_outlined,
            message: 'Belum ada screenshot.',
            hint:
                'Aktifkan monitoring dan pilih interval screenshot di atas.',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 16 / 9,
          ),
          itemCount: state.screenshots.length,
          itemBuilder: (context, i) =>
              _ScreenshotTile(entry: state.screenshots[i], c: c),
        );
      },
    );
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
                    color: c.panelAlt,
                    child: Icon(Icons.broken_image_outlined,
                        color: c.border, size: 32),
                  ),
            // Gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                    Text(timeStr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                    if (entry.appName.isNotEmpty)
                      Text(entry.appName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 9),
                          overflow: TextOverflow.ellipsis),
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
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.appName.isEmpty ? '' : '${entry.appName}  ·  '}${entry.timestamp.toString().substring(0, 19)}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Image.file(File(entry.path), fit: BoxFit.contain),
            const SizedBox(height: 8),
          ],
        ),
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
            Icon(icon, color: c.border, size: 48),
            const SizedBox(height: 12),
            Text(message,
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(hint,
                style: TextStyle(color: c.textMuted, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
