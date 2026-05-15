// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../blocs/recording/recording_bloc.dart';
import '../blocs/file_list/file_list_cubit.dart';
import '../blocs/monitoring/monitoring_cubit.dart';
import '../../data/models/recording_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    context.read<FileListCubit>().load();
    // Auto-start monitoring saat app dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MonitoringCubit>().startMonitoring();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        _PageHeader(c: c),
        Divider(height: 1, thickness: 1, color: c.borderSoft),
        BlocConsumer<RecordingBloc, RecordingState>(
          listener: (context, state) {
            if (state is RecordingIdle && state.lastFile != null) {
              context.read<FileListCubit>().load();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tersimpan: ${state.lastFile}'),
                  action: SnackBarAction(
                    label: 'Buka Folder',
                    onPressed: () => _openFolderPath(state.lastFile!),
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            } else if (state is RecordingError) {
              _showErrorDialog(context, state.message);
            }
          },
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: _RecordingPanel(c: c, state: state),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: _FileListHeader(
            c: c,
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
        ),
        Expanded(child: _FileTable(c: c, filter: _filter)),
      ],
    );
  }

  void _openFolderPath(String filePath) {
    final dir = File(filePath).parent.path;
    if (Platform.isMacOS) {
      Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      Process.run('explorer', [dir]);
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rekaman Gagal'),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<RecordingBloc>().add(StartRecording());
            },
            child: const Text('Coba Lagi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

// ─── Page header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final AppColors c;

  const _PageHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: c.bg,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rekam Layar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  letterSpacing: -0.01 * 15,
                ),
              ),
              Text(
                'Kelola rekaman layar Anda',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
          const Spacer(),
          _HeaderIconBtn(
            icon: Icons.refresh_rounded,
            tooltip: 'Muat Ulang',
            c: c,
            onTap: () => context.read<FileListCubit>().load(),
          ),
          const SizedBox(width: 4),
          _HeaderIconBtn(
            icon: Icons.search_rounded,
            tooltip: 'Cari',
            c: c,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final AppColors c;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: c.textMuted),
        ),
      ),
    );
  }
}

// ─── Recording panel ──────────────────────────────────────────────────────────

class _RecordingPanel extends StatelessWidget {
  final AppColors c;
  final RecordingState state;

  const _RecordingPanel({required this.c, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is RecordingActive) {
      return _ActiveRecordingPanel(c: c, state: state as RecordingActive);
    }
    if (state is RecordingStarting) {
      return _StartingPanel(c: c);
    }
    return _IdlePanel(c: c);
  }
}

class _ActiveRecordingPanel extends StatelessWidget {
  final AppColors c;
  final RecordingActive state;

  const _ActiveRecordingPanel({required this.c, required this.state});

  @override
  Widget build(BuildContext context) {
    final dur = state.duration;
    final hh = dur.inHours.toString().padLeft(2, '0');
    final mm = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = dur.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(
          left: BorderSide(color: c.danger, width: 3),
          top: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          children: [
            // Left: pulsing icon
            _PulsingRecIcon(c: c),
            const SizedBox(width: 14),

            // Middle: status info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sedang merekam',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RecBadge(c: c),
                      const SizedBox(width: 8),
                      Text(
                        '1080p · 30 fps · HEVC',
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.filePath,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: c.textSubtle,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right: timer + stop
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$hh:$mm:$ss',
                  style: TextStyle(
                    fontSize: 22,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'DURASI',
                  style: TextStyle(
                    fontSize: 10,
                    color: c.textMuted,
                    letterSpacing: 0.06,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _AppButton(
                  label: 'Berhenti',
                  icon: Icons.stop_rounded,
                  variant: _ButtonVariant.danger,
                  height: 36,
                  onTap: () => context.read<RecordingBloc>().add(StopRecording()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StartingPanel extends StatelessWidget {
  final AppColors c;

  const _StartingPanel({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.bgMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Memulai rekaman…',
            style: TextStyle(fontSize: 13, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _IdlePanel extends StatelessWidget {
  final AppColors c;

  const _IdlePanel({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.bgMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.videocam_outlined, size: 18, color: c.textSubtle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Siap merekam layar',
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
          ),
          _AppButton(
            label: 'Mulai Rekam',
            icon: Icons.fiber_manual_record,
            variant: _ButtonVariant.danger,
            height: 36,
            onTap: () => context.read<RecordingBloc>().add(StartRecording()),
          ),
        ],
      ),
    );
  }
}

class _PulsingRecIcon extends StatefulWidget {
  final AppColors c;

  const _PulsingRecIcon({required this.c});

  @override
  State<_PulsingRecIcon> createState() => _PulsingRecIconState();
}

class _PulsingRecIconState extends State<_PulsingRecIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: widget.c.dangerSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.c.danger.withValues(alpha: 0.3 + _pulse.value * 0.3),
          ),
        ),
        child: Icon(
          Icons.fiber_manual_record,
          size: 18,
          color: widget.c.danger,
        ),
      ),
    );
  }
}

class _RecBadge extends StatefulWidget {
  final AppColors c;

  const _RecBadge({required this.c});

  @override
  State<_RecBadge> createState() => _RecBadgeState();
}

class _RecBadgeState extends State<_RecBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: widget.c.danger.withValues(alpha: 0.12 + _ctrl.value * 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          'REC',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.c.danger,
            letterSpacing: 0.06,
          ),
        ),
      ),
    );
  }
}

// ─── File list header ─────────────────────────────────────────────────────────

class _FileListHeader extends StatelessWidget {
  final AppColors c;
  final String filter;
  final ValueChanged<String> onFilter;

  const _FileListHeader({
    required this.c,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileListCubit, FileListState>(
      builder: (context, state) {
        final totalBytes = state.entries.fold<int>(0, (s, e) => s + e.sizeBytes);
        final totalMb = totalBytes / (1024 * 1024);
        final sizeLabel = totalMb >= 1024
            ? '${(totalMb / 1024).toStringAsFixed(1)} GB'
            : '${totalMb.toStringAsFixed(0)} MB';
        final count = state.entries.length;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(
                'Rekaman',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count file · $sizeLabel',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
              const Spacer(),
              _SegmentedControl(
                c: c,
                options: const [
                  ('all', 'Semua'),
                  ('today', 'Hari ini'),
                  ('week', 'Minggu ini'),
                ],
                selected: filter,
                onSelect: onFilter,
              ),
            ],
          ),
        );
      },
    );
  }
}

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
        children: options.map((opt) {
          final isSelected = opt.$1 == selected;
          return GestureDetector(
            onTap: () => onSelect(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? c.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))]
                    : null,
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

// ─── File table ───────────────────────────────────────────────────────────────

class _FileTable extends StatelessWidget {
  final AppColors c;
  final String filter;

  const _FileTable({required this.c, required this.filter});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileListCubit, FileListState>(
      builder: (context, state) {
        if (state.loading) {
          return Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2));
        }

        final entries = _filterEntries(state.entries);

        if (entries.isEmpty) {
          return _EmptyState(c: c);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
              color: c.bg,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _TableHeader(c: c),
                Expanded(
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _FileRow(
                      entry: entries[i],
                      c: c,
                      isLast: i == entries.length - 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<RecordingEntry> _filterEntries(List<RecordingEntry> entries) {
    if (filter == 'all') return entries;
    final now = DateTime.now();
    if (filter == 'today') {
      return entries
          .where((e) =>
              e.createdAt.year == now.year &&
              e.createdAt.month == now.month &&
              e.createdAt.day == now.day)
          .toList();
    }
    if (filter == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      return entries.where((e) => e.createdAt.isAfter(weekAgo)).toList();
    }
    return entries;
  }
}

class _TableHeader extends StatelessWidget {
  final AppColors c;

  const _TableHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.bgMuted,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24 + 8),
          Expanded(
            child: _ColLabel('NAMA FILE', c: c),
          ),
          SizedBox(
            width: 110,
            child: _ColLabel('WAKTU', c: c),
          ),
          SizedBox(
            width: 80,
            child: _ColLabel('DURASI', c: c, align: TextAlign.right),
          ),
          SizedBox(
            width: 90,
            child: _ColLabel('UKURAN', c: c, align: TextAlign.right),
          ),
          const SizedBox(width: 120),
        ],
      ),
    );
  }
}

class _ColLabel extends StatelessWidget {
  final String text;
  final AppColors c;
  final TextAlign align;

  const _ColLabel(this.text, {required this.c, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c.textSubtle,
          letterSpacing: 0.06,
        ),
      );
}

class _FileRow extends StatefulWidget {
  final RecordingEntry entry;
  final AppColors c;
  final bool isLast;

  const _FileRow({required this.entry, required this.c, required this.isLast});

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final entry = widget.entry;
    final dateStr = _formatDate(entry.createdAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _hovered ? c.bgHover : Colors.transparent,
          border: widget.isLast
              ? null
              : Border(bottom: BorderSide(color: c.borderSoft)),
        ),
        child: Row(
          children: [
            // File icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: c.bgMuted,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(Icons.movie_outlined, size: 13, color: c.textSubtle),
            ),
            const SizedBox(width: 8),

            // Filename
            Expanded(
              child: Text(
                entry.name,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: c.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Date
            SizedBox(
              width: 110,
              child: Text(
                dateStr,
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ),

            // Duration
            SizedBox(
              width: 80,
              child: Text(
                entry.duration != null ? _fmtDuration(entry.duration!) : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: c.textMuted,
                ),
              ),
            ),

            // Size
            SizedBox(
              width: 90,
              child: Text(
                entry.sizeLabel,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ),

            // Actions
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _RowActionBtn(
                    icon: Icons.drive_file_rename_outline_rounded,
                    tooltip: 'Ganti Nama',
                    c: c,
                    onTap: () => _rename(context, entry),
                  ),
                  _RowActionBtn(
                    icon: Icons.folder_open_rounded,
                    tooltip: 'Buka Folder',
                    c: c,
                    onTap: () => _openFolder(entry),
                  ),
                  _RowActionBtn(
                    icon: Icons.play_circle_outline_rounded,
                    tooltip: 'Putar',
                    c: c,
                    onTap: () => _openFile(entry),
                  ),
                  _RowActionBtn(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Hapus',
                    c: c,
                    onTap: () => _confirmDelete(context, entry),
                    danger: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hari ini ${_pad(dt.hour)}:${_pad(dt.minute)}';
    }
    return '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _openFolder(RecordingEntry entry) {
    final dir = File(entry.path).parent.path;
    if (Platform.isMacOS) {
      Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      Process.run('explorer', [dir]);
    }
  }

  void _openFile(RecordingEntry entry) async {
    final uri = Uri.file(entry.path);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _rename(BuildContext context, RecordingEntry entry) {
    final ctrl = TextEditingController(text: entry.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Nama'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama file'),
          onSubmitted: (_) => _doRename(ctx, entry, ctrl.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () => _doRename(ctx, entry, ctrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _doRename(BuildContext context, RecordingEntry entry, String newName) {
    final name = newName.trim();
    if (name.isEmpty) return;
    final finalName = name.endsWith('.mp4') ? name : '$name.mp4';
    context.read<FileListCubit>().rename(entry, finalName);
    Navigator.pop(context);
  }

  void _confirmDelete(BuildContext context, RecordingEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Rekaman?'),
        content: Text('File "${entry.name}" akan dihapus secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              context.read<FileListCubit>().delete(entry);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _RowActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final AppColors c;
  final VoidCallback onTap;
  final bool danger;

  const _RowActionBtn({
    required this.icon,
    required this.tooltip,
    required this.c,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              icon,
              size: 15,
              color: danger ? c.danger : c.textSubtle,
            ),
          ),
        ),
      );
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppColors c;

  const _EmptyState({required this.c});

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
              child: Icon(Icons.videocam_off_outlined, size: 28, color: c.textFaint),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum ada rekaman',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tekan "Mulai Rekam" untuk memulai',
              style: TextStyle(fontSize: 12, color: c.textSubtle),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared button primitive ─────────────────────────────────────────────────

enum _ButtonVariant { defaultBtn, primary, danger, subtle }

class _AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final _ButtonVariant variant;
  final double height;
  final VoidCallback? onTap;

  const _AppButton({
    required this.label,
    this.icon,
    this.variant = _ButtonVariant.defaultBtn,
    this.height = 28,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final Color bg;
    final Color fg;
    final Color borderColor;

    switch (variant) {
      case _ButtonVariant.primary:
        bg = c.accent;
        fg = Colors.white;
        borderColor = c.accent;
      case _ButtonVariant.danger:
        bg = c.danger;
        fg = Colors.white;
        borderColor = c.danger;
      case _ButtonVariant.subtle:
        bg = Colors.transparent;
        fg = c.textMuted;
        borderColor = Colors.transparent;
      case _ButtonVariant.defaultBtn:
        bg = c.bg;
        fg = c.text;
        borderColor = c.border;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
