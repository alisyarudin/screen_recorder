import 'package:flutter/material.dart';

class AppColors {
  final Color bg;
  final Color bgSubtle;
  final Color bgMuted;
  final Color bgHover;
  final Color bgActive;
  final Color border;
  final Color borderSoft;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color textFaint;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color sidebarBg;
  final Color titlebarBg;

  // Legacy aliases for compat with existing blocs
  Color get panel => bgSubtle;
  Color get panelAlt => bgMuted;
  Color get primary => accent;
  Color get primarySoft => accentSoft;
  Color get warn => warning;
  Color get warnSoft => warningSoft;

  const AppColors._({
    required this.bg,
    required this.bgSubtle,
    required this.bgMuted,
    required this.bgHover,
    required this.bgActive,
    required this.border,
    required this.borderSoft,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.textFaint,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.sidebarBg,
    required this.titlebarBg,
  });

  static const _light = AppColors._(
    bg: Color(0xFFFFFFFF),
    bgSubtle: Color(0xFFFAFAFA),
    bgMuted: Color(0xFFF4F4F5),
    bgHover: Color(0x0A000000),
    bgActive: Color(0x0F000000),
    border: Color(0xFFE4E4E7),
    borderSoft: Color(0xFFEEEEEF),
    borderStrong: Color(0xFFD4D4D8),
    text: Color(0xFF18181B),
    textMuted: Color(0xFF52525B),
    textSubtle: Color(0xFFA1A1AA),
    textFaint: Color(0xFFD4D4D8),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0x1A2563EB),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0x1ADC2626),
    success: Color(0xFF16A34A),
    successSoft: Color(0x1A16A34A),
    warning: Color(0xFFCA8A04),
    warningSoft: Color(0x1FCA8A04),
    sidebarBg: Color(0xFFFAFAFA),
    titlebarBg: Color(0xFFF4F4F5),
  );

  static const _dark = AppColors._(
    bg: Color(0xFF0E0E10),
    bgSubtle: Color(0xFF131316),
    bgMuted: Color(0xFF1A1A1F),
    bgHover: Color(0x0DFFFFFF),
    bgActive: Color(0x14FFFFFF),
    border: Color(0xFF26262B),
    borderSoft: Color(0xFF1E1E22),
    borderStrong: Color(0xFF36363D),
    text: Color(0xFFECECEE),
    textMuted: Color(0xFFA1A1AA),
    textSubtle: Color(0xFF71717A),
    textFaint: Color(0xFF3F3F46),
    accent: Color(0xFF6366F1),
    accentSoft: Color(0x266366F1),
    danger: Color(0xFFEF4444),
    dangerSoft: Color(0x26EF4444),
    success: Color(0xFF22C55E),
    successSoft: Color(0x2622C55E),
    warning: Color(0xFFEAB308),
    warningSoft: Color(0x26EAB308),
    sidebarBg: Color(0xFF131316),
    titlebarBg: Color(0xFF16161A),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}
