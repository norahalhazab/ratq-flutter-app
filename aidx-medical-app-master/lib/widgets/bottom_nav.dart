import 'dart:ui';
import 'package:flutter/material.dart';

import '../screens/Homepage.dart';
import '../screens/cases_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/settings_screen.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.onNewTap,
  });

  final int currentIndex; // 0 home, 1 cases, 2 new, 3 alerts, 4 settings
  final VoidCallback? onNewTap;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  late int _index;

  // sizing
  static const double _barHeight = 92;
  static const double _radius = 22;

  // colors
  static const Color primary = Color(0xFF3B7691); // your blue
  static const Color iconGray = Color(0xFFBFC7D1); // light gray
  static const Color outline = Color(0x22000000);

  static const _tabs = <_TabItem>[
    _TabItem(icon: Icons.home_rounded, label: "Home"),
    _TabItem(icon: Icons.folder_rounded, label: "Cases"),
    _TabItem(icon: Icons.add_rounded, label: "New"),
    _TabItem(icon: Icons.notifications_rounded, label: "Alerts"),
    _TabItem(icon: Icons.person_rounded, label: "Profile"),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex.clamp(0, _tabs.length - 1);
  }

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _index = widget.currentIndex.clamp(0, _tabs.length - 1);
    }
  }

  void _go(int i) {
    if (i == 2) {
      widget.onNewTap?.call();
      return;
    }
    if (i == _index) return;

    setState(() => _index = i);

    final page = switch (i) {
      0 => const Homepage(),
      1 => const CasesScreen(),
      3 => const AlertsScreen(),
      4 => const SettingsScreen(),
      _ => const Homepage(),
    };

    Navigator.pushReplacement(context, _route(page));
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: put this directly in Scaffold.bottomNavigationBar
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, c) {
              final slotW = c.maxWidth / _tabs.length;

              // indicator sizes (like photo)
              const indicatorW = 60.0;
              const indicatorH = 5.0;

              final indicatorLeft = (_index * slotW) + (slotW - indicatorW) / 2;

              return Stack(
                children: [
                  // White bar background
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_radius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: _barHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(_radius),
                          border: Border.all(color: outline, width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ✅ Top indicator line
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: indicatorLeft.clamp(8.0, c.maxWidth - indicatorW - 8.0),
                    top: 6,
                    child: Container(
                      width: indicatorW,
                      height: indicatorH,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  // Tabs
                  Row(
                    children: List.generate(_tabs.length, (i) {
                      final selected = i == _index;

                      return Expanded(
                        child: InkWell(
                          onTap: () => _go(i),
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: _barHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 8), // space under indicator
                                Icon(
                                  _tabs[i].icon,
                                  size: 30,
                                  color: selected ? primary : iconGray,
                                ),
                                const SizedBox(height: 8),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: selected ? 1 : 0,
                                  child: Text(
                                    _tabs[i].label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFBFC7D1),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ---------- model ---------- */
class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

/* ---------- route ---------- */
PageRouteBuilder _route(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
