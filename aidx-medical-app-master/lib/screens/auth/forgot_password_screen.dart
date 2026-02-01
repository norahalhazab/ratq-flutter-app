import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color bgBlue = Color(0xFF2F5D73);

  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg.replaceFirst("Exception: ", ""))),
    );
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _toast("Enter your email");
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      _toast("Reset link sent to your email");
      Navigator.pop(context);
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(height: 20),
              Text(
                "Reset\npassword",
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter your email address and we’ll send you a secure reset link.",
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),

              // ✅ fixed field (no white strip)
              _GlassEmailField(controller: _email),

              const SizedBox(height: 16),

              // ✅ signup-style button
              _LiquidGlassPrimaryButton(
                text: "Send reset link",
                loading: _loading,
                onTap: _loading ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- components ---------------- */

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// ✅ This version removes the “white strip” completely:
/// - uses InputDecoration.collapsed (no padding/background)
/// - sets textAlignVertical center as extra safety
class _GlassEmailField extends StatelessWidget {
  const _GlassEmailField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  enableSuggestions: false,
                  autocorrect: false,
                  textAlignVertical: TextAlignVertical.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: Colors.white,

                  // 🔥 Key fix
                  decoration: InputDecoration.collapsed(
                    hintText: "Email address",
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.7),
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

/// ✅ Same vibe as your Sign-up "Create account" button:
/// - Blur glass
/// - Gradient blue
/// - Border
/// - Rounded 18
class _LiquidGlassPrimaryButton extends StatelessWidget {
  const _LiquidGlassPrimaryButton({
    required this.text,
    required this.loading,
    required this.onTap,
  });

  final String text;
  final bool loading;
  final VoidCallback? onTap;

  static const Color primary = Color(0xFF3B7691);

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: disabled
          ? [primary.withOpacity(0.45), primary.withOpacity(0.20)]
          : [
        const Color(0xFF2E8BC0).withOpacity(0.92),
        primary.withOpacity(0.92),
        const Color(0xFF6FE7FF).withOpacity(0.45),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.45)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
              gradient: gradient,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
