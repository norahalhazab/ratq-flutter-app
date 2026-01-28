import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/dashboard_screen.dart';
import '../screens/cases_screen.dart';
import '../screens/settings_screen.dart';
// import '../screens/alerts_screen.dart'; // if you have it
import '../screens/Homepage.dart';
import '../screens/alerts_screen.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
  });

  final int currentIndex;

  static const primary = Color(0xFF3B7691);
  static const muted = Color(0xFF475569);

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget screen;
    switch (index) {
      case 0:
        screen =  Homepage();
        break;
      case 1:
        screen = const CasesScreen();
        break;
      case 2:
        screen = const AlertsScreen();
        break;

      case 3:
        screen = const SettingsScreen();
        break;
      default:
        screen = const DashboardScreen();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        // fix overflow: give it enough height + less vertical padding
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: const Border(top: BorderSide(color: Color(0x26000000), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: "Home",
              icon: Icons.home_outlined,
              selected: currentIndex == 0,
              onTap: () => _go(context, 0),
            ),
            _NavItem(
              label: "Cases",
              icon: Icons.folder_outlined,
              selected: currentIndex == 1,
              onTap: () => _go(context, 1),
            ),
            _NavItem(
              label: "Alerts",
              icon: Icons.notifications_none,
              selected: currentIndex == 2,
              onTap: () => _go(context, 2),
            ),
            _NavItem(
              label: "Settings",
              icon: Icons.settings_outlined,
              selected: currentIndex == 3,
              onTap: () => _go(context, 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const primary = Color(0xFF3B7691);
  static const muted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final color = selected ? primary : muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3), //  slightly smaller
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis, //  extra safety
              style: GoogleFonts.inter(
                fontSize: 11.0, //  slightly smaller
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.1, //  tighter line height
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsPlaceholder extends StatelessWidget {
  const _AlertsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Alerts screen not added yet")),
    );
  }
}
