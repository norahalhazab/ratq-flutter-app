import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color primary = Color(0xFF3B7691);
  static const Color bgBlue = Color(0xFF3B7691);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- OUTSIDE THE BOX: TOP SECTION ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Reset Password",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            SizedBox(height: 30),// Pushes the box to the center

            // --- THE BOX: CENTERED PANEL ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SlidingAuthCard(
                showLogin: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Please enter your registered email address below to receive reset instructions.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5B5F5F),
                        ),
                      ),
                      const SizedBox(height: 25),
                      _GlassField(
                        label: "Email Address",
                        icon: Icons.mail_outline_rounded,
                        controller: _email,
                        theme: FieldTheme.light,
                      ),
                      const SizedBox(height: 20),
                      _LiquidGlassButton(
                        text: "Send Reset Link",
                        loading: _loading,
                        onTap: _loading ? null : _send,
                        variant: ButtonVariant.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(flex: 2), // Gives more weight to the bottom to keep the box slightly above true center
          ],
        ),
      ),
    );
  }
}

/* ---------------- UI COMPONENTS ---------------- */

class _SlidingAuthCard extends StatelessWidget {
  const _SlidingAuthCard({required this.showLogin, required this.child});
  final bool showLogin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            color: Colors.white.withOpacity(0.88),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 12))
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

enum FieldTheme { light, darkOnBlue, greyLabelOnBlue }

class _GlassField extends StatelessWidget {
  const _GlassField({required this.label, required this.icon, required this.controller, required this.theme});
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final FieldTheme theme;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5B5F5F), fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: const Color(0xFF5B5F5F)),
        filled: true,
        fillColor: const Color(0xFFF2F4F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

enum ButtonVariant { primary, surface, onBlue, onBlueSurface }

class _LiquidGlassButton extends StatelessWidget {
  const _LiquidGlassButton({required this.text, required this.loading, required this.onTap, required this.variant});
  final String text;
  final bool loading;
  final VoidCallback? onTap;
  final ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF3B7691);
    final gradient = LinearGradient(
      colors: onTap == null
          ? [primary.withOpacity(0.45), primary.withOpacity(0.20)]
          : [const Color(0xFF2E8BC0).withOpacity(0.92), primary.withOpacity(0.92), const Color(0xFF6FE7FF).withOpacity(0.45)],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.55)),
              gradient: gradient,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}