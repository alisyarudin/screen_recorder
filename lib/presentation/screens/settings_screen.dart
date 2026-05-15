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

// ignore_for_file: use_build_context_synchronously

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
  late TextEditingController _serverUrlCtrl;
  bool _checking = false;
  bool? _ffmpegOk;
  String? _resolvedFfmpeg;
  bool _autoStart = false;
  bool _hasAdminPassword = false;

  @override
  void initState() {
    super.initState();
    final s = DI.settingsService.load();
    _outputCtrl = TextEditingController(text: s.outputDir);
    _ffmpegCtrl = TextEditingController(text: s.ffmpegPath);
    _serverUrlCtrl = TextEditingController(text: s.serverControlUrl);
    if (Platform.isWindows) _checkFfmpeg();
    if (Platform.isMacOS) _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final autoStart = await DI.adminService.getAutoStartStatus();
    final hasPw = await DI.adminService.hasAdminPassword();
    if (mounted) setState(() { _autoStart = autoStart; _hasAdminPassword = hasPw; });
  }

  @override
  void dispose() {
    _outputCtrl.dispose();
    _ffmpegCtrl.dispose();
    _serverUrlCtrl.dispose();
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
                _qualityDesc(settings.quality, settings.useHevc),
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),

            // ── Video size ────────────────────────────────────────────────────
            _Section(c: c, label: 'UKURAN FILE VIDEO'),
            const SizedBox(height: 10),

            // Frame rate
            Text('Frame Rate', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '15', label: Text('15 fps')),
                ButtonSegment(value: '30', label: Text('30 fps')),
              ],
              selected: {settings.frameRate},
              onSelectionChanged: (v) =>
                  context.read<SettingsCubit>().setFrameRate(v.first),
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
                settings.frameRate == '15'
                    ? '15 fps — file ~50% lebih kecil, cocok untuk rekaman UI/dokumen'
                    : '30 fps — lebih halus, cocok untuk demo animasi/video',
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Max resolution
            Text('Resolusi Maksimal', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'original', label: Text('Original')),
                ButtonSegment(value: '1080p', label: Text('1080p')),
                ButtonSegment(value: '720p', label: Text('720p')),
              ],
              selected: {settings.maxResolution},
              onSelectionChanged: (v) =>
                  context.read<SettingsCubit>().setMaxResolution(v.first),
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
                _resolutionDesc(settings.maxResolution),
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),

            // HEVC — macOS only
            if (Platform.isMacOS) ...[
              _SwitchRow(
                c: c,
                label: 'Gunakan HEVC (H.265)',
                subtitle: 'File ~40% lebih kecil dari H.264 — membutuhkan macOS 13+',
                value: settings.useHevc,
                onChanged: (v) => context.read<SettingsCubit>().setUseHevc(v),
              ),
            ],
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

            // ── Admin ────────────────────────────────────────────────────────
            _Section(c: c, label: 'ADMIN'),
            const SizedBox(height: 8),

            // Auto-start
            _SwitchRow(
              c: c,
              label: 'Jalankan saat Login',
              subtitle: 'App otomatis aktif saat PC dinyalakan (KeepAlive — restart jika ditutup paksa)',
              value: _autoStart,
              onChanged: Platform.isMacOS
                  ? (v) async {
                      final ok = v
                          ? await DI.adminService.installAutoStart()
                          : await DI.adminService.uninstallAutoStart();
                      if (ok && mounted) setState(() => _autoStart = v);
                    }
                  : null,
            ),
            const SizedBox(height: 10),

            // Password admin
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        Text('Password Admin',
                            style: TextStyle(color: c.text, fontSize: 13)),
                        Text(
                          _hasAdminPassword
                              ? 'Password sudah diatur — diperlukan untuk menutup app'
                              : 'Belum diatur — siapapun bisa menutup app',
                          style: TextStyle(
                            color: _hasAdminPassword ? c.success : c.warn,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_hasAdminPassword)
                    OutlinedButton(
                      onPressed: () => _showChangePasswordDialog(c),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.primary,
                        side: BorderSide(color: c.border),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Ubah', style: TextStyle(fontSize: 12)),
                    )
                  else
                    FilledButton(
                      onPressed: () => _showSetPasswordDialog(c),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Set Password', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Server control URL
            _Section(c: c, label: 'KONTROL DARI SERVER'),
            const SizedBox(height: 8),
            TextField(
              controller: _serverUrlCtrl,
              style: TextStyle(color: c.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://admin.perusahaan.com/agent-command',
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: Icon(Icons.save_outlined, size: 18, color: c.primary),
                  tooltip: 'Simpan',
                  onPressed: () async {
                    final url = _serverUrlCtrl.text.trim();
                    await context.read<SettingsCubit>().setServerControlUrl(url);
                    DI.adminService.stopServerPolling();
                    if (url.isNotEmpty) DI.adminService.startServerPolling(url);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL server disimpan')),
                      );
                    }
                  },
                ),
              ),
              onSubmitted: (url) async {
                final trimmed = url.trim();
                await context.read<SettingsCubit>().setServerControlUrl(trimmed);
                DI.adminService.stopServerPolling();
                if (trimmed.isNotEmpty) DI.adminService.startServerPolling(trimmed);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Server merespons JSON: {"command":"exit"} untuk matikan app jarak jauh',
                style: TextStyle(color: c.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),

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

  String _qualityDesc(String q, bool useHevc) => switch (q) {
        'low' => useHevc
            ? 'Rendah — ~800 Kbps (HEVC), cocok untuk rekaman panjang'
            : 'Rendah — ~1.5 Mbps, cocok untuk rekaman panjang',
        'high' => useHevc
            ? 'Tinggi — ~4 Mbps (HEVC), kualitas terbaik'
            : 'Tinggi — ~8 Mbps, kualitas terbaik, file besar',
        _ => useHevc
            ? 'Sedang — ~2 Mbps (HEVC), keseimbangan kualitas dan ukuran'
            : 'Sedang — ~4 Mbps, keseimbangan kualitas dan ukuran',
      };

  String _resolutionDesc(String r) => switch (r) {
        '1080p' => '1080p — cap di 1920×1080, ideal untuk layar Retina/4K',
        '720p' => '720p — cap di 1280×720, file paling kecil',
        _ => 'Original — resolusi penuh display (bisa sangat besar di layar Retina)',
      };

  void _openMacOSSettings() {
    Process.run('open', [
      'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
    ]);
  }

  Future<void> _showSetPasswordDialog(AppColors c) async {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Password Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newCtrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password baru'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Konfirmasi password'),
              onSubmitted: (_) => _doSetPassword(ctx, newCtrl.text, confirmCtrl.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => _doSetPassword(ctx, newCtrl.text, confirmCtrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _doSetPassword(BuildContext ctx, String pw, String confirm) async {
    if (pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password tidak boleh kosong')));
      return;
    }
    if (pw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfirmasi password tidak cocok')));
      return;
    }
    Navigator.pop(ctx);
    final ok = await DI.adminService.setAdminPassword(pw);
    if (mounted) {
      setState(() => _hasAdminPassword = ok);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Password admin berhasil diset' : 'Gagal menyimpan password')));
    }
  }

  Future<void> _showChangePasswordDialog(AppColors c) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Password Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password lama'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password baru'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Konfirmasi password baru'),
              onSubmitted: (_) =>
                  _doChangePassword(ctx, oldCtrl.text, newCtrl.text, confirmCtrl.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                _doChangePassword(ctx, oldCtrl.text, newCtrl.text, confirmCtrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _doChangePassword(
      BuildContext ctx, String old, String newPw, String confirm) async {
    if (newPw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password baru tidak boleh kosong')));
      return;
    }
    if (newPw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfirmasi password tidak cocok')));
      return;
    }
    Navigator.pop(ctx);
    final ok = await DI.adminService.changeAdminPassword(old, newPw);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Password berhasil diubah'
              : 'Password lama salah — coba lagi')));
    }
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
  final ValueChanged<bool>? onChanged;
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
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: c.primary,
            ),
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
