import 'dart:ui';
import 'package:flutter/material.dart';

import '../screens/Homepage.dart';
import '../screens/cases_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/create_case_screen.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
  });

  /// 0=Home, 1=Cases, 2=New, 3=Alerts, 4=Settings
  final int currentIndex;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  late int _index;

  static const double _barH = 80;
  static const double _radius = 30;
  static const double _padX = 16;

  // Ratq blue liquid glass palette
  static const Color _blue1 = Color(0xFF2E8BC0);
  static const Color _blue2 = Color(0xFF3B7691);
  static const Color _blue3 = Color(0xFF6FE7FF);
  static const Color _primary = Color(0xFF3B7691);

  static const _items = <_NavItem>[
    _NavItem(label: "Home", icon: Icons.home_rounded),
    _NavItem(label: "Cases", icon: Icons.folder_rounded),
    _NavItem(label: "New", icon: Icons.add_rounded),
    _NavItem(label: "Alerts", icon: Icons.notifications_rounded),
    _NavItem(label: "Settings", icon: Icons.settings_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex.clamp(0, 4);
  }

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _index = widget.currentIndex.clamp(0, 4);
    }
  }

  Future<void> _goTab(int tabIndex) async {
    // Center: New Case (push)
    if (tabIndex == 2) {
      if (!mounted) return;
      Navigator.push(context, _fadeSlideRoute(const CreateCaseScreen()));
      return;
    }

    if (tabIndex == _index) return;
    setState(() => _index = tabIndex);

    if (!mounted) return;

    Widget screen;
    switch (tabIndex) {
      case 0:
        screen = Homepage();
        break;
      case 1:
        screen = const CasesScreen();
        break;
      case 3:
        screen = const AlertsScreen();
        break;
      case 4:
        screen = const SettingsScreen();
        break;
      default:
        screen = Homepage();
    }

    Navigator.pushReplacement(context, _fadeSlideRoute(screen));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_padX, 0, _padX, 12),
        child: SizedBox(
          height: _barH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(color: Colors.white.withOpacity(0.55)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _blue1.withOpacity(0.35),
                      _blue2.withOpacity(0.35),
                      _blue3.withOpacity(0.25),
                    ],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final slotW = w / _items.length;

                    // Highlight pill behind selected item (icon + label)
                    const pillH = 56.0;
                    final pillW = (slotW * 1.25).clamp(86.0, 150.0);

                    final left = (_index * slotW) + (slotW - pillW) / 2.0;
                    final clampedLeft = left.clamp(6.0, w - pillW - 6.0);

                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: clampedLeft,
                          top: (_barH - pillH) / 2,
                          child: _SelectedPill(width: pillW, height: pillH),
                        ),

                        Row(
                          children: List.generate(_items.length, (i) {
                            final item = _items[i];
                            final selected = i == _index;

                            return Expanded(
                              child: _NavButton(
                                icon: item.icon,
                                label: item.label,
                                selected: selected,
                                isCenterAdd: i == 2,
                                onTap: () => _goTab(i),
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
          ),
        ),
      ),
    );
  }
}

/* ---------------- UI PARTS ---------------- */

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}

class _SelectedPill extends StatelessWidget {
  const _SelectedPill({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.92),
              border: Border.all(color: Colors.white.withOpacity(0.78)),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isCenterAdd,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isCenterAdd;

  static const Color primary = Color(0xFF3B7691);

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? primary : Colors.white.withOpacity(0.92);
    final textColor = selected ? primary : Colors.white.withOpacity(0.92);

    final iconSize = isCenterAdd ? 28.0 : 24.0;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: selected ? 1.05 : 1.0,
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- ROUTE (smooth) ---------------- */

PageRouteBuilder _fadeSlideRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(
        begin: const Offset(0.02, 0),
        end: Offset.zero,
      ).animate(fade);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
