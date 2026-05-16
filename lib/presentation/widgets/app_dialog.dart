// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/di.dart';
import '../../data/models/recording_entry.dart';
import '../../data/models/activity_entry.dart';

// ─── Tone ─────────────────────────────────────────────────────────────────────

enum DialogTone { neutral, accent, danger, warning }

(Color, Color) _toneColors(AppColors c, DialogTone tone) => switch (tone) {
      DialogTone.neutral => (c.bgMuted, c.textMuted),
      DialogTone.accent  => (c.accentSoft, c.accent),
      DialogTone.danger  => (c.dangerSoft, c.danger),
      DialogTone.warning => (c.warningSoft, c.warning),
    };

// ─── Shell ────────────────────────────────────────────────────────────────────

class AppDialogShell extends StatelessWidget {
  final Widget child;
  final double width;

  const AppDialogShell({super.key, required this.child, this.width = 420});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
          decoration: BoxDecoration(
            color: c.bg,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class AppDialogHeader extends StatelessWidget {
  final IconData icon;
  final DialogTone tone;
  final String title;
  final String? subtitle;
  final bool showClose;

  const AppDialogHeader({
    super.key,
    required this.icon,
    this.tone = DialogTone.neutral,
    required this.title,
    this.subtitle,
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (bg, fg) = _toneColors(c, tone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showClose) ...[
            const SizedBox(width: 4),
            _HeaderCloseBtn(c: c),
          ],
        ],
      ),
    );
  }
}

class _HeaderCloseBtn extends StatefulWidget {
  final AppColors c;
  const _HeaderCloseBtn({required this.c});

  @override
  State<_HeaderCloseBtn> createState() => _HeaderCloseBtnState();
}

class _HeaderCloseBtnState extends State<_HeaderCloseBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _hover ? widget.c.bgMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.close, size: 13, color: widget.c.textSubtle),
        ),
      ),
    );
  }
}

// ─── Body & Footer ────────────────────────────────────────────────────────────

class AppDialogBody extends StatelessWidget {
  final Widget child;
  const AppDialogBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: child,
    );
  }
}

class AppDialogFooter extends StatelessWidget {
  final List<Widget> children;
  const AppDialogFooter({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ─── AppTextField ─────────────────────────────────────────────────────────────

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final bool obscureText;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.obscureText = false,
    this.autofocus = false,
    this.errorText,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 12,
              color: c.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          decoration: BoxDecoration(
            color: c.bg,
            border: Border.all(
              color: hasError
                  ? c.danger
                  : (_hasFocus ? c.accent : c.border),
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: _hasFocus && !hasError
                ? [
                    BoxShadow(
                      color: c.accentSoft,
                      spreadRadius: 3,
                      blurRadius: 0,
                    )
                  ]
                : hasError
                    ? [
                        BoxShadow(
                          color: c.dangerSoft,
                          spreadRadius: 3,
                          blurRadius: 0,
                        )
                      ]
                    : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            autofocus: widget.autofocus,
            onSubmitted: widget.onSubmitted,
            style: TextStyle(fontSize: 13, color: c.text),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: TextStyle(color: c.textSubtle),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              isDense: true,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: TextStyle(fontSize: 11, color: c.danger),
          ),
        ],
      ],
    );
  }
}

// ─── AppDialogBtn ─────────────────────────────────────────────────────────────

enum AppBtnKind { subtle, outlined, primary }

class AppDialogBtn extends StatefulWidget {
  final String label;
  final AppBtnKind kind;
  final bool danger;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AppDialogBtn(
    this.label, {
    super.key,
    this.kind = AppBtnKind.outlined,
    this.danger = false,
    this.loading = false,
    required this.onPressed,
    this.icon,
  });

  @override
  State<AppDialogBtn> createState() => _AppDialogBtnState();
}

class _AppDialogBtnState extends State<AppDialogBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final Color fg;
    final Color bg;
    final Border? border;

    switch (widget.kind) {
      case AppBtnKind.primary:
        fg = Colors.white;
        bg = widget.danger ? c.danger : c.accent;
        border = null;
      case AppBtnKind.subtle:
        fg = widget.danger ? c.danger : c.textMuted;
        bg = _hover ? c.bgMuted : Colors.transparent;
        border = null;
      case AppBtnKind.outlined:
        fg = widget.danger ? c.danger : c.text;
        bg = _hover ? c.bgMuted : Colors.transparent;
        border = Border.all(color: widget.danger ? c.dangerSoft : c.border);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: fg,
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 12, color: fg),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Rename Dialog ────────────────────────────────────────────────────────────

class _RenameDialog extends StatefulWidget {
  final String currentName;
  const _RenameDialog({required this.currentName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final n = widget.currentName;
    _ctrl = TextEditingController(
        text: n.toLowerCase().endsWith('.mp4') ? n.substring(0, n.length - 4) : n);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name.endsWith('.mp4') ? name : '$name.mp4');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final trimmed = _ctrl.text.trim();
    final preview = trimmed.isEmpty
        ? ''
        : '→ ${trimmed.endsWith('.mp4') ? trimmed : '$trimmed.mp4'}';

    return AppDialogShell(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogHeader(
            icon: Icons.edit_outlined,
            tone: DialogTone.accent,
            title: 'Ganti nama rekaman',
            subtitle: 'Ekstensi .mp4 akan ditambahkan otomatis',
          ),
          AppDialogBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _ctrl,
                  label: 'Nama file baru',
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppDialogFooter(
            children: [
              AppDialogBtn(
                'Batal',
                kind: AppBtnKind.subtle,
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppDialogBtn(
                'Simpan',
                kind: AppBtnKind.primary,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> showRenameDialog(BuildContext context, String currentName) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(currentName: currentName),
  );
}

// ─── Delete Dialog ────────────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final RecordingEntry entry;
  const _DeleteDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    String durStr = '';
    if (entry.duration != null) {
      final d = entry.duration!;
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      durStr = h > 0 ? '$h:$m:$s' : '$m:$s';
    }

    return AppDialogShell(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogHeader(
            icon: Icons.delete_outline,
            tone: DialogTone.danger,
            title: 'Hapus rekaman?',
            subtitle:
                'File akan dipindahkan ke Trash. Anda dapat memulihkannya dari sana.',
          ),
          AppDialogBody(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.bgMuted,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.bg,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child:
                        Icon(Icons.movie_outlined, size: 13, color: c.textMuted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                            color: c.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            entry.sizeLabel,
                            if (durStr.isNotEmpty) durStr,
                          ].join(' · '),
                          style: TextStyle(fontSize: 11, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppDialogFooter(
            children: [
              AppDialogBtn(
                'Batal',
                kind: AppBtnKind.subtle,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              AppDialogBtn(
                'Hapus',
                kind: AppBtnKind.outlined,
                danger: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> showDeleteDialog(BuildContext context, RecordingEntry entry) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _DeleteDialog(entry: entry),
      ) ??
      false;
}

// ─── Password Dialog (stop monitoring / app close) ────────────────────────────

class _PasswordDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final bool allowClose;

  const _PasswordDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    this.allowClose = true,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await DI.adminService.verifyAdminPassword(_ctrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = 'Password salah';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(
            icon: Icons.lock_outline,
            tone: DialogTone.warning,
            title: widget.title,
            subtitle: widget.subtitle,
            showClose: widget.allowClose,
          ),
          AppDialogBody(
            child: AppTextField(
              controller: _ctrl,
              label: 'Password admin',
              obscureText: true,
              autofocus: true,
              errorText: _error,
              onSubmitted: (_) => _submit(),
            ),
          ),
          AppDialogFooter(
            children: [
              if (widget.allowClose)
                AppDialogBtn(
                  'Batal',
                  kind: AppBtnKind.subtle,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              AppDialogBtn(
                widget.confirmLabel,
                kind: AppBtnKind.primary,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> showPasswordDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String confirmLabel,
  bool allowClose = true,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: allowClose,
        builder: (_) => _PasswordDialog(
          title: title,
          subtitle: subtitle,
          confirmLabel: confirmLabel,
          allowClose: allowClose,
        ),
      ) ??
      false;
}

// ─── Set Password Dialog ──────────────────────────────────────────────────────

class _SetPasswordDialog extends StatefulWidget {
  const _SetPasswordDialog();

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pw = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pw.isEmpty || pw != confirm) return;
    Navigator.of(context).pop((pw, confirm));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogHeader(
            icon: Icons.lock_outline,
            tone: DialogTone.accent,
            title: 'Set password admin',
            subtitle:
                'Password diperlukan untuk menutup atau menghentikan monitoring',
          ),
          AppDialogBody(
            child: Column(
              children: [
                AppTextField(
                  controller: _newCtrl,
                  label: 'Password baru',
                  obscureText: true,
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Konfirmasi password',
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          AppDialogFooter(
            children: [
              AppDialogBtn(
                'Batal',
                kind: AppBtnKind.subtle,
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppDialogBtn(
                'Simpan',
                kind: AppBtnKind.primary,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<(String, String)?> showSetPasswordDialog(BuildContext context) {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => const _SetPasswordDialog(),
  );
}

// ─── Change Password Dialog ───────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _matches =>
      _newCtrl.text.isNotEmpty && _newCtrl.text == _confirmCtrl.text;

  void _submit() {
    if (!_matches || _oldCtrl.text.isEmpty) return;
    Navigator.of(context).pop((_oldCtrl.text, _newCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppDialogShell(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogHeader(
            icon: Icons.lock_outline,
            tone: DialogTone.accent,
            title: 'Ubah password admin',
            subtitle:
                'Masukkan password saat ini, lalu password baru dua kali',
          ),
          AppDialogBody(
            child: Column(
              children: [
                AppTextField(
                  controller: _oldCtrl,
                  label: 'Password saat ini',
                  obscureText: true,
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _newCtrl,
                  label: 'Password baru',
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Konfirmasi password baru',
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_matches) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check, size: 12, color: c.success),
                      const SizedBox(width: 6),
                      Text(
                        'Password cocok',
                        style: TextStyle(fontSize: 11.5, color: c.success),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          AppDialogFooter(
            children: [
              AppDialogBtn(
                'Batal',
                kind: AppBtnKind.subtle,
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppDialogBtn(
                'Simpan Password',
                kind: AppBtnKind.primary,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<(String, String)?> showChangePasswordDialog(BuildContext context) {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

// ─── Recording Error Dialog ───────────────────────────────────────────────────

class _RecordingErrorDialog extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RecordingErrorDialog({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppDialogShell(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogHeader(
            icon: Icons.info_outline,
            tone: DialogTone.danger,
            title: 'Gagal memulai rekaman',
            subtitle:
                'Periksa izin Screen Recording di System Settings.',
          ),
          AppDialogBody(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.bgMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: c.textMuted,
                  height: 1.5,
                ),
              ),
            ),
          ),
          AppDialogFooter(
            children: [
              AppDialogBtn(
                'Tutup',
                kind: AppBtnKind.subtle,
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppDialogBtn(
                'Buka System Settings',
                kind: AppBtnKind.outlined,
                icon: Icons.open_in_new,
                onPressed: () {
                  Navigator.of(context).pop();
                  Process.run('open', [
                    'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
                  ]);
                },
              ),
              AppDialogBtn(
                'Coba Lagi',
                kind: AppBtnKind.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showRecordingErrorDialog(
    BuildContext context, String message, VoidCallback onRetry) {
  showDialog<void>(
    context: context,
    builder: (_) => _RecordingErrorDialog(message: message, onRetry: onRetry),
  );
}

// ─── Screenshot Fullscreen Viewer ─────────────────────────────────────────────

class _ScreenshotFullscreen extends StatelessWidget {
  final ScreenshotEntry entry;
  final List<ScreenshotEntry> allScreenshots;
  final int currentIndex;

  const _ScreenshotFullscreen({
    required this.entry,
    required this.allScreenshots,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';
    final initials =
        entry.appName.isNotEmpty ? entry.appName[0].toUpperCase() : '?';

    return Dialog(
      backgroundColor: const Color(0xFF0A0A0A),
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            // Topbar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0x14FFFFFF)),
                ),
              ),
              child: Row(
                children: [
                  if (entry.appName.isNotEmpty) ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.appName.isNotEmpty
                              ? entry.appName
                              : 'Screenshot',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0x80FFFFFF),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DarkBtn(
                    label: 'Buka di Finder',
                    icon: Icons.open_in_new,
                    onTap: () {
                      final dir = File(entry.path).parent.path;
                      Process.run('open', [dir]);
                    },
                  ),
                  const SizedBox(width: 8),
                  _DarkIconBtn(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Image viewport
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 80,
                            offset: const Offset(0, 24),
                          ),
                        ],
                        border:
                            Border.all(color: const Color(0x0DFFFFFF)),
                      ),
                      child: Image.file(
                        File(entry.path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 400,
                          height: 300,
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0x40FFFFFF),
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pagination dots
            if (allScreenshots.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < allScreenshots.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == currentIndex ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == currentIndex
                              ? Colors.white
                              : const Color(0x40FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DarkBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DarkBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_DarkBtn> createState() => _DarkBtnState();
}

class _DarkBtnState extends State<_DarkBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0x1AFFFFFF)
                : const Color(0x0DFFFFFF),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DarkIconBtn({required this.icon, required this.onTap});

  @override
  State<_DarkIconBtn> createState() => _DarkIconBtnState();
}

class _DarkIconBtnState extends State<_DarkIconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0x1AFFFFFF)
                : const Color(0x0DFFFFFF),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 13, color: Colors.white),
        ),
      ),
    );
  }
}

void showScreenshotFullscreen(
  BuildContext context,
  ScreenshotEntry entry, {
  List<ScreenshotEntry>? allScreenshots,
}) {
  final shots = allScreenshots ?? [entry];
  final idx = shots.indexWhere((s) => s.path == entry.path);
  showDialog<void>(
    context: context,
    builder: (_) => _ScreenshotFullscreen(
      entry: entry,
      allScreenshots: shots,
      currentIndex: idx < 0 ? 0 : idx,
    ),
  );
}
