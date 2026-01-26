import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  DateTime? _surgeryDate;
  bool _loading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _surgeryDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _surgeryDate = picked);
    }
  }

  Future<void> _createCase() async {
    if (_surgeryDate == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .add({
      'title': 'Case ${DateTime.now().millisecondsSinceEpoch}',
      'status': 'active',
      'infectionScore': 0,
      'surgeryDate': Timestamp.fromDate(_surgeryDate!),
      'startDate': Timestamp.fromDate(_surgeryDate!),
      'lastUpdated': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Colors matching your CSS
    const primary = Color(0xFF3B7691);
    const inputBg = Color(0x1A3B7691); // #3b76911a
    const lightGrey = Color(0x80D9D9D9); // #d9d9d980
    const borderGrey = Color(0xFFD9D9D9);

    final dd = _surgeryDate == null ? "DD" : _two(_surgeryDate!.day);
    final mm = _surgeryDate == null ? "MM" : _two(_surgeryDate!.month);
    final yyyy = _surgeryDate == null ? "YYYY" : _surgeryDate!.year.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scroll content (leave space for bottom nav)
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top navigation (like HTML top-navigation)
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                        ),
                        const Spacer(),
                        Text(
                          "Create Case",
                          style: GoogleFonts.syne(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2F3131),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48), // to balance back button
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Title container (Create New Case / subtitle) like .container
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Create New Case",
                          style: GoogleFonts.dmSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F1729),
                            height: 32 / 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Start monitoring a new wound",
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF0F1729),
                            height: 18 / 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section title (Select the date...)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      "Select the date when the surgery was performed",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFBFBFBF),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Date input field (DD/MM/YYYY boxes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Surgery Date",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _DateBox(text: dd, onTap: _pickDate, bg: inputBg, border: borderGrey)),
                            const SizedBox(width: 8),
                            Expanded(child: _DateBox(text: mm, onTap: _pickDate, bg: inputBg, border: borderGrey)),
                            const SizedBox(width: 8),
                            Expanded(child: _DateBox(text: yyyy, onTap: _pickDate, bg: inputBg, border: borderGrey)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Grey rectangle + "What happens next?"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            color: lightGrey,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "What happens next?",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  height: 16.8 / 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "After creating the case, you'll be able to start the\n"
                                    "daily monitoring workflow which includes\n"
                                    "capturing wound images, syncing vitals, and completing the\n"
                                    "WHQ questionnaire.",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF757575),
                                  height: 13.2 / 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Buttons row (Cancel / Create Case) like pills
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _loading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: primary, width: 1),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.syne(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 140,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _createCase,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: primary, width: 1),
                              shape: const StadiumBorder(),
                            ),
                            child: _loading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : Text(
                              "Create Case",
                              style: GoogleFonts.syne(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Fixed bottom nav (same as your HTML)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: _BottomNavLikeHtml(selectedIndex: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.text,
    required this.onTap,
    required this.bg,
    required this.border,
  });

  final String text;
  final VoidCallback onTap;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF1E1E1E),
          ),
        ),
      ),
    );
  }
}

class _BottomNavLikeHtml extends StatelessWidget {
  const _BottomNavLikeHtml({required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF3B7691);

    Color itemColor(bool selected) => selected ? primary : primary; // HTML كله نفس اللون تقريبًا

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
          _NavItem(label: "Home", icon: Icons.home_outlined, selected: selectedIndex == 0, color: itemColor(selectedIndex == 0)),
          _NavItem(label: "Cases", icon: Icons.folder_outlined, selected: selectedIndex == 1, color: itemColor(selectedIndex == 1)),
          _NavItem(label: "Alerts", icon: Icons.notifications_none, selected: selectedIndex == 2, color: itemColor(selectedIndex == 2)),
          _NavItem(label: "Settings", icon: Icons.settings_outlined, selected: selectedIndex == 3, color: itemColor(selectedIndex == 3)),
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
    required this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
              fontSize: selected ? 11.6 : 10.9,
              fontWeight: FontWeight.w600,
              color: color,
              height: 16 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
