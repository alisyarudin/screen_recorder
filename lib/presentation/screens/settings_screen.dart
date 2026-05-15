import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/app_colors.dart';
import '../../core/di.dart';
import '../../core/settings_service.dart';
import '../blocs/settings/settings_cubit.dart';
import '../blocs/file_list/file_list_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        title: Text('Pengaturan', style: TextStyle(color: c.text, fontSize: 15)),
        iconTheme: IconThemeData(color: c.textMuted),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.border),
        ),
      ),
      body: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  late TextEditingController _outputCtrl;
  late TextEditingController _ffmpegCtrl;
  bool _checking = false;
  bool? _ffmpegOk;
  String? _resolvedFfmpeg;

  @override
  void initState() {
    super.initState();
    final s = DI.settingsService.load();
    _outputCtrl = TextEditingController(text: s.outputDir);
    _ffmpegCtrl = TextEditingController(text: s.ffmpegPath);
    if (Platform.isWindows) _checkFfmpeg();
  }

  @override
  void dispose() {
    _outputCtrl.dispose();
    _ffmpegCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    setState(() {
      _checking = true;
      _resolvedFfmpeg = null;
    });
    final found = await DI.screenRecordingService.findFfmpeg(_ffmpegCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _ffmpegOk = found != null;
      _resolvedFfmpeg = found;
      _checking = false;
      if (found != null && found != 'ffmpeg' && _ffmpegCtrl.text.trim().isEmpty) {
        _ffmpegCtrl.text = found;
      }
    });
  }

  Future<void> _pickOutputDir() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      setState(() => _outputCtrl.text = result);
      await context.read<SettingsCubit>().setOutputDir(result);
      if (mounted) context.read<FileListCubit>().load();
    }
  }

  Future<void> _saveOutputDir(String val) async {
    await context.read<SettingsCubit>().setOutputDir(val.trim());
    if (mounted) context.read<FileListCubit>().load();
  }

  Future<void> _saveFfmpegPath(String val) async {
    await context.read<SettingsCubit>().setFfmpegPath(val.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<SettingsCubit, RecorderSettings>(
      builder: (context, settings) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Output folder ────────────────────────────────────────────────
            _Section(c: c, label: 'FOLDER OUTPUT'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _outputCtrl,
                    style: TextStyle(color: c.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '~/ScreenRecordings (default)',
                      hintStyle: TextStyle(color: c.textMuted),
                      filled: true,
                      fillColor: c.panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: c.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: _saveOutputDir,
                    onEditingComplete: () => _saveOutputDir(_outputCtrl.text),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickOutputDir,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Pilih'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.border),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Quality ──────────────────────────────────────────────────────
            _Section(c: c, label: 'KUALITAS VIDEO'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Rendah')),
                ButtonSegment(value: 'medium', label: Text('Sedang')),
                ButtonSegment(value: 'high', label: Text('Tinggi')),
              ],
              selected: {settings.quality},
              onSelectionChanged: (v) =>
                  context.read<SettingsCubit>().setQuality(v.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return c.primary;
                  return c.panel;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return c.text;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _qualityDesc(settings.quality),
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),

            // ── Always on top ────────────────────────────────────────────────
            _Section(c: c, label: 'JENDELA'),
            const SizedBox(height: 8),
            _SwitchRow(
              c: c,
              label: 'Selalu di atas',
              subtitle: 'Jendela app tidak tertutup oleh app lain',
              value: settings.alwaysOnTop,
              onChanged: (v) async {
                await context.read<SettingsCubit>().setAlwaysOnTop(v);
                await windowManager.setAlwaysOnTop(v);
              },
            ),
            const SizedBox(height: 20),

            // ── FFmpeg (Windows only) ────────────────────────────────────────
            if (Platform.isWindows) ...[
              _Section(c: c, label: 'FFMPEG (WINDOWS)'),
              const SizedBox(height: 8),
              _FfmpegStatus(c: c, ok: _ffmpegOk, checking: _checking, path: _resolvedFfmpeg),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ffmpegCtrl,
                      style: TextStyle(color: c.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: r'C:\ffmpeg\bin\ffmpeg.exe  (kosong = cari otomatis)',
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: c.panel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: c.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (v) async {
                        await _saveFfmpegPath(v);
                        _checkFfmpeg();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await _saveFfmpegPath(_ffmpegCtrl.text);
                      _checkFfmpeg();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.primary,
                      side: BorderSide(color: c.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    child: const Text('Cek'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_ffmpegOk == false && !_checking) _FfmpegGuide(c: c),
              const SizedBox(height: 20),
            ],

            // ── macOS permission ─────────────────────────────────────────────
            if (Platform.isMacOS) ...[
              _Section(c: c, label: 'IZIN macOS'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rekam layar memerlukan izin Screen Recording.',
                      style: TextStyle(color: c.text, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _openMacOSSettings,
                      icon: Icon(Icons.open_in_new, size: 15, color: c.primary),
                      label: Text('Buka System Settings',
                          style: TextStyle(color: c.primary)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── About ────────────────────────────────────────────────────────
            _Section(c: c, label: 'TENTANG'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Screen Recorder',
                      style: TextStyle(
                          color: c.text, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Versi 1.0.0',
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    Platform.isMacOS
                        ? 'macOS — menggunakan ScreenCaptureKit (H.264 MP4)'
                        : 'Windows — menggunakan FFmpeg (gdigrab)',
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _qualityDesc(String q) => switch (q) {
        'low' => 'Rendah — file kecil, cocok untuk rekaman panjang (1.5 Mbps)',
        'high' => 'Tinggi — kualitas terbaik, file besar (8 Mbps)',
        _ => 'Sedang — keseimbangan kualitas dan ukuran file (4 Mbps)',
      };

  void _openMacOSSettings() {
    Process.run('open', [
      'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
    ]);
  }
}

class _Section extends StatelessWidget {
  final AppColors c;
  final String label;
  const _Section({required this.c, required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color: c.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  final AppColors c;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.c,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: c.text, fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(color: c.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged, activeColor: c.primary),
          ],
        ),
      );
}

class _FfmpegStatus extends StatelessWidget {
  final AppColors c;
  final bool? ok;
  final bool checking;
  final String? path;
  const _FfmpegStatus(
      {required this.c, required this.ok, required this.checking, this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: checking
            ? c.panelAlt
            : (ok == true ? c.successSoft : c.dangerSoft),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (checking)
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
          else
            Icon(
              ok == true ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: ok == true ? c.success : c.danger,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checking
                      ? 'Mencari FFmpeg…'
                      : (ok == true
                          ? 'FFmpeg ditemukan — siap merekam'
                          : 'FFmpeg tidak ditemukan'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: checking
                        ? c.textMuted
                        : (ok == true ? c.success : c.danger),
                  ),
                ),
                if (ok == true && path != null)
                  Text(path!, style: TextStyle(fontSize: 11, color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FfmpegGuide extends StatelessWidget {
  final AppColors c;
  const _FfmpegGuide({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.warn.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cara Install FFmpeg di Windows:',
              style: TextStyle(
                  color: c.text, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          _step(c, '1.', 'Buka PowerShell sebagai Administrator'),
          _step(c, '2.', 'Jalankan: winget install ffmpeg'),
          _step(c, '   ', 'atau: choco install ffmpeg'),
          _step(c, '3.', 'Restart aplikasi setelah instalasi selesai'),
        ],
      ),
    );
  }

  Widget _step(AppColors c, String num, String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(num, style: TextStyle(color: c.warn, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(text, style: TextStyle(color: c.text, fontSize: 12))),
          ],
        ),
      );
}
