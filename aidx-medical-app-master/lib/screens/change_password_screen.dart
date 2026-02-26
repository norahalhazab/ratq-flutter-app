import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();

  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  // App Colors
  static const bg = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3B7691);
  static const cardBg = Color(0xFFEFF6FB);
  static const fieldBg = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast("No user logged in");
      return;
    }

    final email = user.email;
    if (email == null) {
      _toast("User email not found");
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: _currentPw.text.trim(),
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPw.text.trim());

      _toast("Password updated successfully");
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    } catch (_) {
      _toast("Something went wrong");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: textMuted, size: 28,),
                    const SizedBox(width: 10),
                    Text(
                      'Change Password',
                      style: GoogleFonts.dmSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Current password'),
                      _passwordField(
                        controller: _currentPw,
                        obscure: !_showCurrent,
                        onToggle: () =>
                            setState(() => _showCurrent = !_showCurrent),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your current password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _label('New password'),
                      _passwordField(
                        controller: _newPw,
                        obscure: !_showNew,
                        onToggle: () =>
                            setState(() => _showNew = !_showNew),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Enter a new password';
                          if (s.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _label('Confirm new password'),
                      _passwordField(
                        controller: _confirmPw,
                        obscure: !_showConfirm,
                        onToggle: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) {
                            return 'Confirm your new password';
                          }
                          if (s != _newPw.text.trim()) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 10),
                      Text(
                        'Use at least 6 characters. \n Avoid reusing old passwords.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // ✅ Only Update Password button
                Center(
                  child: SizedBox(
                    width:
                    MediaQuery.of(context).size.width * 0.85,
                    child: ElevatedButton(
                      onPressed:
                      _loading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor:
                        primary.withOpacity(0.6),
                        elevation: 0,
                        padding:
                        const EdgeInsets.symmetric(
                            vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        'Update password',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight:
                          FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 14.5,
        color: textDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: fieldBg,
        contentPadding:
        const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide:
          const BorderSide(
              color: primary, width: 1.2),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility
                : Icons.visibility_off,
            color: textMuted,
          ),
        ),
      ),
    );
  }
}