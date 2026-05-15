import 'package:flutter/material.dart';

class AppColors {
  final Color bg;
  final Color panel;
  final Color panelAlt;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color primarySoft;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warn;
  final Color warnSoft;

  const AppColors._({
    required this.bg,
    required this.panel,
    required this.panelAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warn,
    required this.warnSoft,
  });

  static const _light = AppColors._(
    bg: Color(0xFFF5F5F7),
    panel: Color(0xFFFFFFFF),
    panelAlt: Color(0xFFF0F0F2),
    border: Color(0xFFDDDDE0),
    text: Color(0xFF1C1C1E),
    textMuted: Color(0xFF8E8E93),
    primary: Color(0xFF0C7A8C),
    primarySoft: Color(0xFFE0F4F7),
    success: Color(0xFF34C759),
    successSoft: Color(0xFFE8F8ED),
    danger: Color(0xFFFF3B30),
    dangerSoft: Color(0xFFFFECEB),
    warn: Color(0xFFFF9500),
    warnSoft: Color(0xFFFFF3E0),
  );

  static const _dark = AppColors._(
    bg: Color(0xFF1C1C1E),
    panel: Color(0xFF2C2C2E),
    panelAlt: Color(0xFF3A3A3C),
    border: Color(0xFF48484A),
    text: Color(0xFFF2F2F7),
    textMuted: Color(0xFF8E8E93),
    primary: Color(0xFF45BDCE),
    primarySoft: Color(0xFF1A3540),
    success: Color(0xFF32D74B),
    successSoft: Color(0xFF1A3320),
    danger: Color(0xFFFF453A),
    dangerSoft: Color(0xFF3A1A1A),
    warn: Color(0xFFFF9F0A),
    warnSoft: Color(0xFF3A2A10),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  }
}
