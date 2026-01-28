import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart'; // <--- 1. Import your navigation file

class UploadSuccessScreen extends StatelessWidget {
  const UploadSuccessScreen({super.key});

  static const Color _primary = Color(0xFF3B7691);
  static const Color _dark = Color(0xFF0F1729);
  static const Color _uploadBg = Color(0x6663A2BF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // 2. Use the real AppBottomNav (Index 1 = Cases)
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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

              // Success card
              Container(
                width: double.infinity,
                height: 335,
                decoration: BoxDecoration(
                  color: _uploadBg,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  children: [
                    // Background Shape
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

                    // Check Icon
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

// 3. REMOVED: The temporary _BottomNav and _NavItem classes are deleted.