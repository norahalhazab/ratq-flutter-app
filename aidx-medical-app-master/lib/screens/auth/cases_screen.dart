import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFFFFF);
    final surface = const Color(0xFFF8FAFC);
    final primary = const Color(0xFF3B7691);
    final secondary = const Color(0xFF63A2BF);
    final danger = const Color(0xFFBF121D);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header area (system bar spacing + button)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
              child: Row(
                children: [
                  const Spacer(),
                  _PrimaryButton(
                    label: "New Case",
                    color: primary,
                    icon: Icons.add,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // Title + subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "My Cases",
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    height: 32 / 24,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Track your wound healing progress",
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF0F172A),
                    height: 24 / 16,
                  ),
                ),
              ),
            ),

            // Section label: Active cases
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Active Cases",
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                      height: 24 / 16,
                    ),
                  ),
                ],
              ),
            ),

            // Scroll content (cards)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 90),
                children: [
                  CaseCard(
                    surface: surface,
                    primary: primary,
                    accent: secondary,
                    tagText: "No Signs of Infection",
                    tagColor: secondary,
                    tagTextColor: primary,
                    iconGradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF465467),
                        Color(0xFFA4C9DA),
                      ],
                    ),
                    title: "Case 1",
                    day: "Day 5",
                    startDate: "2025-01-10",
                    lastUpdated: "2025-01-15",
                    score: "2",
                    onDashboard: () {},
                    onDetails: () {},
                  ),
                  const SizedBox(height: 18),
                  CaseCard(
                    surface: surface,
                    primary: primary,
                    accent: secondary,
                    tagText: "High Risk",
                    tagColor: danger,
                    tagTextColor: danger,
                    iconGradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFBF121D),
                        Color(0xFFF8FAFC),
                      ],
                    ),
                    title: "Case 2",
                    day: "Day 8",
                    startDate: "2025-01-08",
                    lastUpdated: "2025-01-16",
                    score: "5",
                    onDashboard: () {},
                    onDetails: () {},
                    isDanger: true,
                  ),
                  const SizedBox(height: 18),

                  // Closed section
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: secondary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Closed Cases",
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                          height: 24 / 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  CaseCard(
                    surface: surface,
                    primary: primary,
                    accent: secondary,
                    tagText: "No Signs of Infection",
                    tagColor: secondary,
                    tagTextColor: primary,
                    iconGradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF465467),
                        Color(0xFFA4C9DA),
                      ],
                    ),
                    title: "Case 3",
                    day: "Day 25",
                    startDate: "2024-12-20",
                    lastUpdated: "2025-01-05",
                    score: "1",
                    onDashboard: () {},
                    onDetails: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom nav
      bottomNavigationBar: _BottomNav(primary: primary),
    );
  }
}

class CaseCard extends StatelessWidget {
  const CaseCard({
    super.key,
    required this.surface,
    required this.primary,
    required this.accent,
    required this.tagText,
    required this.tagColor,
    required this.tagTextColor,
    required this.iconGradient,
    required this.title,
    required this.day,
    required this.startDate,
    required this.lastUpdated,
    required this.score,
    required this.onDashboard,
    required this.onDetails,
    this.isDanger = false,
  });

  final Color surface;
  final Color primary;
  final Color accent;

  final String tagText;
  final Color tagColor; // used as border base too
  final Color tagTextColor;

  final LinearGradient iconGradient;

  final String title;
  final String day;
  final String startDate;
  final String lastUpdated;
  final String score;

  final VoidCallback onDashboard;
  final VoidCallback onDetails;

  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final text = const Color(0xFF0F172A);
    final muted = const Color(0xFF36404F);
    final border = const Color(0xFFC8D3DF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        children: [
          // top row: icon + title/day + tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(gradient: iconGradient),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: text,
                        height: 28 / 18,
                      ),
                    ),
                    Text(
                      day,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: text,
                        height: 20 / 14,
                      ),
                    ),
                  ],
                ),
              ),
              _TagChip(
                text: tagText,
                color: tagColor,
                textColor: isDanger ? tagColor : primary,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Start date + last updated label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "      Start Date                           Last Updated",
              style: GoogleFonts.inter(
                fontSize: 12.9,
                fontWeight: FontWeight.w400,
                color: muted,
                height: 20 / 12.9,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // dates row
          Row(
            children: [
              _DateRow(icon: Icons.calendar_today_outlined, label: startDate),
              const SizedBox(width: 16),
              _DateRow(icon: Icons.access_time, label: lastUpdated),
            ],
          ),

          const SizedBox(height: 16),

          // divider + score
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: border, width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  "Infection Score",
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: text,
                    height: 20 / 14,
                  ),
                ),
                const Spacer(),
                Text(
                  score,
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: text,
                    height: 32 / 24,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // actions
          SizedBox(
            height: 26,
            child: Row(
              children: [
                _ActionChip(
                  label: "View Details",
                  color: accent,
                  textColor: primary,
                  onTap: onDetails,
                ),
                const SizedBox(width: 10),
                _ActionChip(
                  label: "View Dashboard",
                  color: accent,
                  textColor: primary,
                  onTap: onDashboard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF0F172A),
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.gradient});

  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF63A2BF).withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.folder_outlined, color: Colors.white, size: 24),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.4,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 16 / 11.4,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.1,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 20 / 13.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 120,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF63A2BF).withOpacity(0.20),
              blurRadius: 15,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFF8FAFC)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFF8FAFC),
                height: 20 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 57,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(top: BorderSide(color: Color(0x26000000), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(label: "Home", icon: Icons.home_outlined, selected: false, primary: primary),
          _NavItem(label: "Cases", icon: Icons.folder_outlined, selected: true, primary: primary),
          _NavItem(label: "Alerts", icon: Icons.notifications_none, selected: false, primary: primary),
          _NavItem(label: "Settings", icon: Icons.settings_outlined, selected: false, primary: primary),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final color = selected ? primary : const Color(0xFF475569);

    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.6,
              fontWeight: FontWeight.w600,
              color: color,
              height: 16 / 11.6,
            ),
          ),
        ],
      ),
    );
  }
}
