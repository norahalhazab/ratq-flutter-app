import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/bottom_nav.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String? _selectedCaseId;

  // UI colors (clean + close to your screenshot)
  static const bg = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFF7F7F7);
  static const border = Color(0x11000000);
  static const titleColor = Color(0xFF111827);
  static const mutedText = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: Text("User not logged in")),
      );
    }

    final casesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true);

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const _PageTitle(title: "Dashboard"),
              const SizedBox(height: 16),

              // ---- 2x2 cards like the screenshot ----
              Row(
                children: const [
                  Expanded(
                    child: _MetricCard(
                      label: "Heart\nRate",
                      value: "---",
                      unit: "bpm",
                      badgeText: "Not synced",
                      icon: Icons.favorite_border,
                      iconBg: Color(0xFFFFE5E5),
                      iconColor: Color(0xFFD14B4B),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: _MetricCard(
                      label: "Blood\nPressure",
                      value: "--- / ---",
                      unit: "mmHg",
                      badgeText: "Not synced",
                      icon: Icons.water_drop_outlined,
                      iconBg: Color(0xFFE3F8FF),
                      iconColor: Color(0xFF0E7490),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: _MetricCard(
                      label: "Temperature",
                      value: "---",
                      unit: "°C",
                      badgeText: "Not synced",
                      icon: Icons.thermostat_outlined,
                      iconBg: Color(0xFFFFF1DD),
                      iconColor: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ✅ Infection score from selected case
                  Expanded(
                    child: _SelectedCaseInfectionCard(
                      selectedCaseId: _selectedCaseId,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ---- Case selector (from Firestore) ----
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: casesQuery.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Text("Error loading cases");
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;

                  // If no cases
                  if (docs.isEmpty) {
                    return _CaseSelector(
                      enabled: false,
                      selectedCaseId: null,
                      items: const [],
                      onChanged: (_) {},
                      helperText: "No cases yet — create one first",
                    );
                  }

                  // If selected is null or not found, pick first (use addPostFrame to avoid setState in build)
                  final ids = docs.map((d) => d.id).toList();
                  if (_selectedCaseId == null || !ids.contains(_selectedCaseId)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _selectedCaseId = ids.first);
                    });
                  }

                  final items = docs.map((d) {
                    final data = d.data();
                    final title = (data['title'] ?? 'Case').toString();
                    return _CaseItem(id: d.id, title: title);
                  }).toList();

                  return _CaseSelector(
                    enabled: true,
                    selectedCaseId: _selectedCaseId ?? ids.first,
                    items: items,
                    onChanged: (id) => setState(() => _selectedCaseId = id),
                    helperText: "Choose which case to show (sync later)",
                  );
                },
              ),

              const SizedBox(height: 14),

              const Spacer(),

              const Text(
                "Smartwatch sync: coming soon (values will replace ---)",
                style: TextStyle(color: mutedText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- Infection card (selected case) ---------------- */

class _SelectedCaseInfectionCard extends StatelessWidget {
  const _SelectedCaseInfectionCard({required this.selectedCaseId});
  final String? selectedCaseId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // If no user or no selected case yet
    if (user == null || selectedCaseId == null) {
      return const _MetricCard(
        label: "Infection\nScore",
        value: "---",
        unit: "",
        badgeText: "Select a case",
        icon: Icons.show_chart,
        iconBg: Color(0xFFEFF6FF),
        iconColor: Color(0xFF1D4ED8),
      );
    }

    final caseDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .doc(selectedCaseId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: caseDoc.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _MetricCard(
            label: "Infection\nScore",
            value: "---",
            unit: "",
            badgeText: "Error",
            icon: Icons.show_chart,
            iconBg: Color(0xFFEFF6FF),
            iconColor: Color(0xFF1D4ED8),
          );
        }

        if (!snap.hasData || snap.data?.data() == null) {
          return const _MetricCard(
            label: "Infection\nScore",
            value: "---",
            unit: "",
            badgeText: "Loading...",
            icon: Icons.show_chart,
            iconBg: Color(0xFFEFF6FF),
            iconColor: Color(0xFF1D4ED8),
          );
        }

        final data = snap.data!.data()!;

        // ✅ Uses the same field you used in CaseDetailsScreen
        final raw = data['infectionScore'];
        final int? score = raw is int ? raw : int.tryParse('$raw');

        return _MetricCard(
          label: "Infection\nScore",
          value: score?.toString() ?? "---",
          unit: "",
          badgeText: score == null ? "No data yet" : "From selected case",
          icon: Icons.show_chart,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF1D4ED8),
        );
      },
    );
  }
}

/* ---------------- UI widgets ---------------- */

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return const Text(
      "Dashboard",
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.badgeText,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String label;
  final String value;
  final String unit;
  final String badgeText;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  static const cardBg = Color(0xFFF7F7F7);
  static const border = Color(0x11000000);
  static const titleColor = Color(0xFF111827);
  static const mutedText = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 12,
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _CaseItem {
  final String id;
  final String title;
  const _CaseItem({required this.id, required this.title});
}

class _CaseSelector extends StatelessWidget {
  const _CaseSelector({
    required this.enabled,
    required this.selectedCaseId,
    required this.items,
    required this.onChanged,
    required this.helperText,
  });

  final bool enabled;
  final String? selectedCaseId;
  final List<_CaseItem> items;
  final ValueChanged<String?> onChanged;
  final String helperText;

  static const border = Color(0x11000000);
  static const mutedText = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: enabled ? selectedCaseId : null,
              hint: const Text("Case ID"),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: items
                  .map(
                    (c) => DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(
                    c.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helperText,
          style: const TextStyle(color: mutedText, fontSize: 12),
        ),
      ],
    );
  }
}
