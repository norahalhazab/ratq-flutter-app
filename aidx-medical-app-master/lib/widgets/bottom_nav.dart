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

  /// 0 home, 1 cases, 2 new, 3 alerts, 4 settings
  final int currentIndex;
  final VoidCallback? onNewTap;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  late int _index;

  // sizing
  static const double _barH = 78;
  static const double _radius = 24;

  // highlight "square" size
  static const double _pillW = 54;
  static const double _pillH = 54;
  static const double _pillR = 18;

  // colors
  static const Color barWhite = Colors.white;
  static const Color iconColor = Color(0xFF0F172A); // unselected (requested)
  static const Color outline = Color(0x11000000);

  static const Color blueA = Color(0xFF63A2BF); // glossy base (requested family)
  static const Color blueB = Color(0xFF3B7691); // deeper blue from your theme

  // ✅ hollow icons (outlined)
  static const _tabs = <_TabItem>[
    _TabItem(icon: Icons.home_outlined),
    _TabItem(icon: Icons.folder_outlined),
    _TabItem(icon: Icons.add),
    _TabItem(icon: Icons.notifications_none_outlined),
    _TabItem(icon: Icons.settings_outlined),
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
    // ✅ touches the bottom edge (no SafeArea bottom here)
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: _barH,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final slotW = w / _tabs.length;

            final left = (_index * slotW) + (slotW - _pillW) / 2;
            final top = (_barH - _pillH) / 2;

            return Stack(
              children: [
                // Bar background
                Container(
                  height: _barH,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: barWhite,
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

                // ✅ glossy liquid blue "square" highlight
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  left: left.clamp(10, w - _pillW - 10),
                  top: top,
                  child: _GlossySquircle(
                    width: _pillW,
                    height: _pillH,
                    radius: _pillR,
                  ),
                ),

                // icons
                Row(
                  children: List.generate(_tabs.length, (i) {
                    final selected = i == _index;

                    return Expanded(
                      child: InkWell(
                        onTap: () => _go(i),
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: _barH,
                          child: Center(
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              scale: selected ? 1.06 : 1.0,
                              child: Icon(
                                _tabs[i].icon,
                                size: 26,
                                color: selected ? Colors.white : iconColor,
                              ),
                            ),
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
    );
  }
}

/* ---------- glossy squircle ---------- */

class _GlossySquircle extends StatelessWidget {
  const _GlossySquircle({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  static const Color blue = Color(0xFF63A2BF);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // base blue gradient (liquid-ish)
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: blue, // ✅ بدون gradient
                borderRadius: BorderRadius.circular(radius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
            ),

            // glossy highlight streak
            Positioned(
              top: -10,
              left: -12,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: width * 1.2,
                  height: height * 0.55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.55),
                        Colors.white.withOpacity(0.00),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // subtle inner border for “gloss”
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
                ),
              ),
            ),

            // tiny blur overlay to make it feel “liquid”
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- model ---------- */
class _TabItem {
  final IconData icon;
  const _TabItem({required this.icon});
}

/* ---------- route ---------- */
PageRouteBuilder _route(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
