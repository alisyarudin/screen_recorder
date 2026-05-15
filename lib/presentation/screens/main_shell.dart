// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../blocs/recording/recording_bloc.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Row(
        children: [
          _Sidebar(c: c, index: _index, onTap: (i) => setState(() => _index = i)),
          VerticalDivider(width: 1, thickness: 1, color: c.borderSoft),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                DashboardScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final AppColors c;
  final int index;
  final ValueChanged<int> onTap;

  const _Sidebar({required this.c, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: c.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workspace pill
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: c.bgMuted,
                border: Border.all(color: c.borderSoft),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.fiber_manual_record, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agent Workspace',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'agent',
                          style: TextStyle(fontSize: 10, color: c.textMuted, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nav group: WORKSPACE
          _NavGroupLabel('WORKSPACE', c: c),
          _NavItem(
            icon: Icons.videocam_outlined,
            label: 'Rekam Layar',
            active: index == 0,
            c: c,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.monitor_heart_outlined,
            label: 'Dashboard',
            active: index == 1,
            c: c,
            onTap: () => onTap(1),
          ),
          const SizedBox(height: 8),

          // Nav group: SISTEM
          _NavGroupLabel('SISTEM', c: c),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Pengaturan',
            active: index == 2,
            c: c,
            onTap: () => onTap(2),
          ),

          const Spacer(),

          // Recording status footer
          BlocBuilder<RecordingBloc, RecordingState>(
            builder: (_, state) {
              if (state is! RecordingActive) return const SizedBox.shrink();
              final d = state.duration;
              final hh = d.inHours.toString().padLeft(2, '0');
              final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
              final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.dangerSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      _RecDot(c: c),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEREKAM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: c.danger,
                                letterSpacing: 0.04,
                              ),
                            ),
                            Text(
                              '$hh:$mm:$ss',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                                color: c.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavGroupLabel extends StatelessWidget {
  final String label;
  final AppColors c;

  const _NavGroupLabel(this.label, {required this.c});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
            color: c.textSubtle,
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final AppColors c;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? c.bgActive : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: active ? c.accent : c.textSubtle),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  color: active ? c.text : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecDot extends StatefulWidget {
  final AppColors c;

  const _RecDot({required this.c});

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.c.danger,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.c.danger.withValues(alpha: (1 - _anim.value) * 0.55),
              blurRadius: _anim.value * 8,
              spreadRadius: _anim.value * 2,
            ),
          ],
        ),
      ),
    );
  }
}
