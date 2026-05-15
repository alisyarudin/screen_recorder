import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../blocs/recording/recording_bloc.dart';
import '../blocs/file_list/file_list_cubit.dart';
import '../blocs/monitoring/monitoring_cubit.dart';
import '../../data/models/recording_entry.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _TitleBar(c: c),
          _RecordingBar(c: c),
          const Divider(height: 1),
          Expanded(child: _RecordingList(c: c)),
        ],
      ),
    );
  }
}

// ─── Title bar ────────────────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  final AppColors c;
  const _TitleBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_rounded, color: c.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Screen Recorder',
            style: TextStyle(
              color: c.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          BlocBuilder<FileListCubit, FileListState>(
            builder: (context, state) => IconButton(
              tooltip: 'Muat Ulang Daftar',
              icon: Icon(Icons.refresh_rounded, color: c.textMuted, size: 18),
              onPressed: () => context.read<FileListCubit>().load(),
            ),
          ),
          IconButton(
            tooltip: 'Dashboard Monitoring',
            icon: Icon(Icons.monitor_heart_outlined, color: c.textMuted, size: 18),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: Icon(Icons.settings_outlined, color: c.textMuted, size: 18),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recording bar ────────────────────────────────────────────────────────────

class _RecordingBar extends StatelessWidget {
  final AppColors c;
  const _RecordingBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordingBloc, RecordingState>(
      listener: (context, state) {
        if (state is RecordingIdle && state.lastFile != null) {
          context.read<FileListCubit>().load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tersimpan: ${state.lastFile}'),
              action: SnackBarAction(
                label: 'Buka Folder',
                onPressed: () => _openFolder(state.lastFile!),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        } else if (state is RecordingError) {
          _showErrorDialog(context, state.message);
        }
      },
      builder: (context, state) {
        final isActive = state is RecordingActive;
        final isStarting = state is RecordingStarting;
        final isError = state is RecordingError;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: c.panel,
          child: Row(
            children: [
              _RecordButton(c: c, state: state),
              const SizedBox(width: 16),
              Expanded(child: _RecordingStatus(c: c, state: state)),
              if (isActive)
                TextButton.icon(
                  onPressed: () => context.read<RecordingBloc>().add(StopRecording()),
                  icon: Icon(Icons.stop_circle_outlined, color: c.danger, size: 18),
                  label: Text('Berhenti', style: TextStyle(color: c.danger)),
                ),
              if (!isActive && !isStarting && !isError)
                FilledButton.icon(
                  onPressed: () => context.read<RecordingBloc>().add(StartRecording()),
                  icon: const Icon(Icons.fiber_manual_record, size: 16),
                  label: const Text('Mulai Rekam'),
                  style: FilledButton.styleFrom(backgroundColor: c.danger),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openFolder(String filePath) {
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

class _RecordButton extends StatefulWidget {
  final AppColors c;
  final RecordingState state;
  const _RecordButton({required this.c, required this.state});

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
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
    final isActive = widget.state is RecordingActive;
    final c = widget.c;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? c.danger.withValues(alpha: 0.15 + _pulse.value * 0.1)
              : c.panelAlt,
          border: Border.all(
            color: isActive
                ? c.danger.withValues(alpha: 0.5 + _pulse.value * 0.5)
                : c.border,
            width: 2,
          ),
        ),
        child: Icon(
          isActive ? Icons.stop_rounded : Icons.fiber_manual_record,
          color: isActive ? c.danger : c.textMuted,
          size: 22,
        ),
      ),
    );
  }
}

class _RecordingStatus extends StatelessWidget {
  final AppColors c;
  final RecordingState state;
  const _RecordingStatus({required this.c, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is RecordingActive) {
      final s = state as RecordingActive;
      final dur = s.duration;
      final hh = dur.inHours.toString().padLeft(2, '0');
      final mm = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
      final timeStr = dur.inHours > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.danger),
              ),
              Text(
                'Merekam — $timeStr',
                style: TextStyle(color: c.danger, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(s.filePath, style: TextStyle(color: c.textMuted, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ],
      );
    }
    if (state is RecordingStarting) {
      return Row(
        children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
          const SizedBox(width: 8),
          Text('Memulai rekaman…', style: TextStyle(color: c.textMuted, fontSize: 13)),
        ],
      );
    }
    return Text(
      'Siap merekam layar',
      style: TextStyle(color: c.textMuted, fontSize: 13),
    );
  }
}

// ─── Recording list ───────────────────────────────────────────────────────────

class _RecordingList extends StatelessWidget {
  final AppColors c;
  const _RecordingList({required this.c});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileListCubit, FileListState>(
      builder: (context, state) {
        if (state.loading) {
          return Center(child: CircularProgressIndicator(color: c.primary));
        }
        if (state.entries.isEmpty) {
          return _EmptyState(c: c);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '${state.entries.length} rekaman',
                style: TextStyle(
                    color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: state.entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) =>
                    _RecordingItem(entry: state.entries[i], c: c),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, color: c.border, size: 48),
          const SizedBox(height: 12),
          Text('Belum ada rekaman', style: TextStyle(color: c.textMuted, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            'Tekan "Mulai Rekam" untuk memulai',
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RecordingItem extends StatelessWidget {
  final RecordingEntry entry;
  final AppColors c;
  const _RecordingItem({required this.entry, required this.c});

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(entry.createdAt);
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.movie_rounded, color: c.primary, size: 20),
        ),
        title: Text(
          entry.name,
          style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$dateStr  ·  ${entry.sizeLabel}',
          style: TextStyle(color: c.textMuted, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(
              context,
              Icons.drive_file_rename_outline_rounded,
              'Ganti Nama',
              () => _rename(context, entry),
              c,
            ),
            _iconBtn(
              context,
              Icons.folder_open_rounded,
              'Buka Folder',
              () => _openFolder(entry),
              c,
            ),
            _iconBtn(
              context,
              Icons.play_circle_outline_rounded,
              'Putar',
              () => _openFile(entry),
              c,
            ),
            _iconBtn(
              context,
              Icons.delete_outline_rounded,
              'Hapus',
              () => _confirmDelete(context, entry),
              c,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    AppColors c, {
    bool danger = false,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: danger ? c.danger : c.textMuted),
          ),
        ),
      );

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hari ini ${_pad(dt.hour)}:${_pad(dt.minute)}';
    }
    return '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

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
