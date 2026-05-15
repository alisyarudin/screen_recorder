// ignore_for_file: use_build_context_synchronously
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
    return Column(
      children: [
        _SettingsHeader(c: c),
        Divider(height: 1, thickness: 1, color: c.borderSoft),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsToc(c: c),
              Container(width: 1, color: c.borderSoft),
              const Expanded(child: _SettingsBody()),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Settings header ──────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  final AppColors c;

  const _SettingsHeader({required this.c});

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
                'Pengaturan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  letterSpacing: -0.01 * 15,
                ),
              ),
              Text(
                'Konfigurasi rekaman, monitoring, dan keamanan',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── TOC ──────────────────────────────────────────────────────────────────────

class _SettingsToc extends StatelessWidget {
  final AppColors c;

  const _SettingsToc({required this.c});

  @override
  Widget build(BuildContext context) {
    const sections = [
      'Folder Output',
      'Kualitas Video',
      'Ukuran File',
      'Jendela',
      'Izin macOS',
      'Admin',
      'Kontrol Server',
      'Tentang',
    ];

    return Container(
      width: 200,
      color: c.bgSubtle,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              'PENGATURAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08,
                color: c.textSubtle,
              ),
            ),
          ),
          ...sections.map((s) => _TocItem(label: s, c: c)),
        ],
      ),
    );
  }
}

class _TocItem extends StatelessWidget {
  final String label;
  final AppColors c;

  const _TocItem({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
      ),
    );
  }
}

// ─── Settings body ────────────────────────────────────────────────────────────

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

  Future<void> _saveFfmpegPath(String val) async {
    await context.read<SettingsCubit>().setFfmpegPath(val.trim());
  }

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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BlocBuilder<SettingsCubit, RecorderSettings>(
      builder: (context, settings) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 28, 32),
          children: [
            // ── Folder Output ────────────────────────────────────────────────
            _SectionLabel(c: c, label: 'FOLDER OUTPUT', hint: 'Lokasi penyimpanan file rekaman'),
            const SizedBox(height: 10),
            _SettingsCard(
              c: c,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.bgMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _outputCtrl.text.isEmpty ? '~/ScreenRecordings (default)' : _outputCtrl.text,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: _outputCtrl.text.isEmpty ? c.textSubtle : c.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _OutlineBtn(
                          label: 'Pilih Folder',
                          icon: Icons.folder_open_outlined,
                          c: c,
                          onTap: _pickOutputDir,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Kualitas Video ───────────────────────────────────────────────
            _SectionLabel(c: c, label: 'KUALITAS VIDEO', hint: 'Bitrate dan codec rekaman'),
            const SizedBox(height: 10),
            _SettingsCard(
              c: c,
              child: Column(
                children: [
                  _SettingsRow(
                    c: c,
                    label: 'Preset',
                    isFirst: true,
                    trailing: _SegmentedSetting(
                      c: c,
                      options: const [
                        ('low', 'Rendah'),
                        ('medium', 'Sedang'),
                        ('high', 'Tinggi'),
                      ],
                      selected: settings.quality,
                      onSelect: (v) => context.read<SettingsCubit>().setQuality(v),
                    ),
                  ),
                  _SettingsRow(
                    c: c,
                    label: 'Bitrate',
                    isFirst: false,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.bgMuted,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _bitrateLabel(settings.quality, settings.useHevc),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: c.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Ukuran File ──────────────────────────────────────────────────
            _SectionLabel(c: c, label: 'UKURAN FILE', hint: 'Frame rate, resolusi, dan codec output'),
            const SizedBox(height: 10),
            _SettingsCard(
              c: c,
              child: Column(
                children: [
                  _SettingsRow(
                    c: c,
                    label: 'Frame Rate',
                    isFirst: true,
                    trailing: _SegmentedSetting(
                      c: c,
                      options: const [
                        ('15', '15 fps'),
                        ('30', '30 fps'),
                      ],
                      selected: settings.frameRate,
                      onSelect: (v) => context.read<SettingsCubit>().setFrameRate(v),
                    ),
                  ),
                  _SettingsRow(
                    c: c,
                    label: 'Resolusi',
                    isFirst: false,
                    trailing: _SegmentedSetting(
                      c: c,
                      options: const [
                        ('original', 'Original'),
                        ('1080p', '1080p'),
                        ('720p', '720p'),
                      ],
                      selected: settings.maxResolution,
                      onSelect: (v) => context.read<SettingsCubit>().setMaxResolution(v),
                    ),
                  ),
                  if (Platform.isMacOS)
                    _ToggleRow(
                      c: c,
                      label: 'Gunakan HEVC (H.265)',
                      subtitle: 'File ~40% lebih kecil · macOS 13+',
                      isFirst: false,
                      value: settings.useHevc,
                      onChanged: (v) => context.read<SettingsCubit>().setUseHevc(v),
                      badge: _Badge(label: 'macOS', c: c, color: c.accent),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Jendela ──────────────────────────────────────────────────────
            _SectionLabel(c: c, label: 'JENDELA', hint: 'Perilaku jendela aplikasi'),
            const SizedBox(height: 10),
            _SettingsCard(
              c: c,
              child: _ToggleRow(
                c: c,
                label: 'Selalu di atas',
                subtitle: 'Jendela app tidak tertutup oleh app lain',
                isFirst: true,
                value: settings.alwaysOnTop,
                onChanged: (v) async {
                  await context.read<SettingsCubit>().setAlwaysOnTop(v);
                  await windowManager.setAlwaysOnTop(v);
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── FFmpeg (Windows only) ────────────────────────────────────────
            if (Platform.isWindows) ...[
              _SectionLabel(c: c, label: 'FFMPEG (WINDOWS)', hint: 'Path ke binary FFmpeg'),
              const SizedBox(height: 10),
              _SettingsCard(
                c: c,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FfmpegStatus(c: c, ok: _ffmpegOk, checking: _checking, path: _resolvedFfmpeg),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ffmpegCtrl,
                              style: TextStyle(color: c.text, fontSize: 12, fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                hintText: r'C:\ffmpeg\bin\ffmpeg.exe',
                                hintStyle: TextStyle(color: c.textSubtle, fontSize: 12),
                                filled: true,
                                fillColor: c.bgMuted,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: c.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: c.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              onSubmitted: (v) async {
                                await _saveFfmpegPath(v);
                                _checkFfmpeg();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _OutlineBtn(
                            label: 'Cek',
                            c: c,
                            onTap: () async {
                              await _saveFfmpegPath(_ffmpegCtrl.text);
                              _checkFfmpeg();
                            },
                          ),
                        ],
                      ),
                      if (_ffmpegOk == false && !_checking) ...[
                        const SizedBox(height: 8),
                        _FfmpegGuide(c: c),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Izin macOS ───────────────────────────────────────────────────
            if (Platform.isMacOS) ...[
              _SectionLabel(c: c, label: 'IZIN macOS', hint: 'Izin yang diperlukan untuk merekam layar'),
              const SizedBox(height: 10),
              _SettingsCard(
                c: c,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.warningSoft,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: c.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Rekam layar memerlukan izin Screen Recording di System Settings.',
                            style: TextStyle(fontSize: 12, color: c.text),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _OutlineBtn(
                          label: 'System Settings',
                          icon: Icons.open_in_new_rounded,
                          c: c,
                          onTap: _openMacOSSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Admin ────────────────────────────────────────────────────────
            _SectionLabel(c: c, label: 'ADMIN', hint: 'Keamanan dan akses administratif'),
            const SizedBox(height: 10),
            _SettingsCard(
              c: c,
              child: Column(
                children: [
                  _ToggleRow(
                    c: c,
                    label: 'Jalankan saat Login',
                    subtitle: 'App otomatis aktif saat PC dinyalakan',
                    isFirst: true,
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
                  // Password admin row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.borderSoft)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c.bgMuted,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            Icons.lock_outlined,
                            size: 16,
                            color: _hasAdminPassword ? c.success : c.textSubtle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password Admin',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: c.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  _Badge(
                                    label: _hasAdminPassword ? 'DIATUR' : 'BELUM DIATUR',
                                    c: c,
                                    color: _hasAdminPassword ? c.success : c.warning,
                                    softColor: _hasAdminPassword ? c.successSoft : c.warningSoft,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _hasAdminPassword
                                        ? 'Diperlukan untuk menutup app'
                                        : 'Siapapun bisa menutup app',
                                    style: TextStyle(fontSize: 11, color: c.textSubtle),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_hasAdminPassword)
                          _OutlineBtn(
                            label: 'Ubah Password',
                            c: c,
                            onTap: () => _showChangePasswordDialog(c),
                          )
                        else
                          _PrimaryBtn(
                            label: 'Set Password',
                            c: c,
                            onTap: () => _showSetPasswordDialog(c),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Kontrol Server ───────────────────────────────────────────────
            _SectionLabel(c: c, label: 'KONTROL SERVER', hint: 'Terima perintah dari server jarak jauh'),
            const SizedBox(height: 10),
            _SettingsCard(
              c: c,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _serverUrlCtrl,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: 'https://admin.perusahaan.com/agent-command',
                        hintStyle: TextStyle(color: c.textSubtle, fontSize: 12),
                        filled: true,
                        fillColor: c.bgMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: c.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.save_outlined, size: 16, color: c.accent),
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
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.bgMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 13, color: c.textSubtle),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Server merespons JSON: {"command":"exit"} untuk matikan app jarak jauh',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: c.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Tentang ──────────────────────────────────────────────────────
            _SectionLabel(c: c, label: 'TENTANG', hint: 'Informasi versi aplikasi'),
            const SizedBox(height: 10),
            _SettingsCard(
              c: c,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Screen Recorder',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Versi 1.0.0',
                            style: TextStyle(fontSize: 12, color: c.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Platform.isMacOS
                                ? 'macOS · ScreenCaptureKit · H.264/HEVC MP4'
                                : 'Windows · FFmpeg · gdigrab',
                            style: TextStyle(fontSize: 11, color: c.textSubtle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _bitrateLabel(String q, bool useHevc) => switch (q) {
        'low' => useHevc ? '~800 Kbps' : '~1.5 Mbps',
        'high' => useHevc ? '~4 Mbps' : '~8 Mbps',
        _ => useHevc ? '~2 Mbps' : '~4 Mbps',
      };
}

// ─── Shared UI primitives ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final AppColors c;
  final String label;
  final String hint;

  const _SectionLabel({required this.c, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Text(
          hint,
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final AppColors c;
  final Widget child;

  const _SettingsCard({required this.c, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final AppColors c;
  final String label;
  final bool isFirst;
  final Widget trailing;

  const _SettingsRow({
    required this.c,
    required this.label,
    required this.isFirst,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: isFirst ? BorderSide.none : BorderSide(color: c.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final AppColors c;
  final String label;
  final String subtitle;
  final bool isFirst;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? badge;

  const _ToggleRow({
    required this.c,
    required this.label,
    required this.subtitle,
    required this.isFirst,
    required this.value,
    required this.onChanged,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: isFirst ? BorderSide.none : BorderSide(color: c.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.text,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      badge!,
                    ],
                  ],
                ),
                Text(subtitle, style: TextStyle(fontSize: 11, color: c.textSubtle)),
              ],
            ),
          ),
          _AppToggle(value: value, onChanged: onChanged, c: c),
        ],
      ),
    );
  }
}

class _AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final AppColors c;

  const _AppToggle({required this.value, required this.onChanged, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 18,
        decoration: BoxDecoration(
          color: value ? c.accent : c.bgMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: value ? c.accent : c.border),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedSetting extends StatelessWidget {
  final AppColors c;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentedSetting({
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

class _Badge extends StatelessWidget {
  final String label;
  final AppColors c;
  final Color color;
  final Color? softColor;

  const _Badge({
    required this.label,
    required this.c,
    required this.color,
    this.softColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: softColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AppColors c;
  final VoidCallback onTap;

  const _OutlineBtn({
    required this.label,
    this.icon,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: c.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final AppColors c;
  final VoidCallback onTap;

  const _PrimaryBtn({required this.label, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _FfmpegStatus extends StatelessWidget {
  final AppColors c;
  final bool? ok;
  final bool checking;
  final String? path;

  const _FfmpegStatus({
    required this.c,
    required this.ok,
    required this.checking,
    this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: checking
            ? c.bgMuted
            : (ok == true ? c.successSoft : c.dangerSoft),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          if (checking)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
            )
          else
            Icon(
              ok == true ? Icons.check_circle_outline : Icons.error_outline,
              size: 15,
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
                  Text(
                    path!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: c.textMuted,
                    ),
                  ),
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
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara Install FFmpeg di Windows:',
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
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
            Text(
              num,
              style: TextStyle(color: c.warning, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, style: TextStyle(color: c.text, fontSize: 12)),
            ),
          ],
        ),
      );
}
