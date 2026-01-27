import 'package:flutter/material.dart';

class UploadSuccessScreen extends StatelessWidget {
  const UploadSuccessScreen({super.key});

  static const Color _primary = Color(0xFF3B7691);
  static const Color _dark = Color(0xFF0F1729);
  static const Color _uploadBg = Color(0x6663A2BF); // #63a2bf40

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const _BottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (arrow aligned to top line like your Case screen)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _dark),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Capture Wound Image",
                          style: TextStyle(
                            fontFamily: "DM Sans",
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                            height: 32 / 24,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Take a clear photo of your wound for analysis",
                          style: TextStyle(
                            fontFamily: "DM Sans",
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: _dark,
                            height: 24 / 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Success card (matches the big blue rounded area)
              Container(
                width: double.infinity,
                height: 335,
                decoration: BoxDecoration(
                  color: _uploadBg,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  children: [
                    // Big soft oval background (approximation of your rotated circle)
                    Positioned(
                      top: -220,
                      left: -60,
                      child: Container(
                        width: 470,
                        height: 619,
                        decoration: BoxDecoration(
                          color: _uploadBg,
                          borderRadius: BorderRadius.circular(310),
                        ),
                      ),
                    ),

                    // Check icon (use your own asset if you have it)
                    const Align(
                      alignment: Alignment(0, -0.25),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.check_circle, size: 90, color: _primary),
                      ),
                    ),

                    // Text
                    const Align(
                      alignment: Alignment(0, 0.55),
                      child: Text(
                        "Image uploaded\nsuccessfully.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "DM Sans",
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                          height: 32 / 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    // TODO: Navigate to vitals screen when ready
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => const VitalsScreen()));
                  },
                  child: const Text(
                    "Continue to vitals",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: 13.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  static const Color primary = Color(0xFF3B7691);
  static const Color muted = Color(0xFF475569);

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
        children: const [
          _NavItem(label: "Home", icon: Icons.home_outlined, selected: false),
          _NavItem(label: "Cases", icon: Icons.folder_outlined, selected: true),
          _NavItem(label: "Alerts", icon: Icons.notifications_none, selected: false),
          _NavItem(label: "Settings", icon: Icons.settings_outlined, selected: false),
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
  });

  final String label;
  final IconData icon;
  final bool selected;

  static const Color primary = Color(0xFF3B7691);
  static const Color muted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final color = selected ? primary : muted;

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: "Inter",
                fontSize: 11.6,
                fontWeight: FontWeight.w600,
                height: 16 / 11.6,
              ).copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
