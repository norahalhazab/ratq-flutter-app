import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../Homepage.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Brand
  static const Color primary = Color(0xFF3B7691);
  static const Color bgBlue = Color(0xFF3B7691);

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _password = TextEditingController();

  final _nameR = TextEditingController();
  final _emailR = TextEditingController();
  final _passR = TextEditingController();
  final _confirmR = TextEditingController();

  bool _loading = false;
  bool _showLogin = true;

  // show/hide password
  bool _showPw = false;
  bool _showPwR = false;
  bool _showPwC = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nameR.dispose();
    _emailR.dispose();
    _passR.dispose();
    _confirmR.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Homepage()),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg.replaceFirst("Exception: ", ""))),
    );
  }

  Future<void> _loginEmail() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final user = await auth.signInWithEmailAndPassword(
        _email.text.trim(),
        _password.text.trim(),
      );
      if (user != null) await _goHome();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerEmail() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final user = await auth.registerWithEmailAndPassword(
        _emailR.text.trim(),
        _passR.text.trim(),
        _nameR.text.trim(),
      );
      if (user != null) {
        setState(() => _showLogin = true);
        _toast("Account created. Please login.");
      }
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final user = await auth.signInWithGoogle();
      if (user != null) await _goHome();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginApple() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final user = await auth.signInWithApple();
      if (user != null) await _goHome();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      // ✅ background changes with tab
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        color: _showLogin ? bgBlue : Colors.white, // Login blue / Signup white
        child: SafeArea(
          child: Column(
            children: [
              // ✅ header adapts text colors
              _TopHeader(onWhite: !_showLogin),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: _SlidingAuthCard(
                    showLogin: _showLogin,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Column(
                        children: [
                          _AuthSwitchLiquid(
                            leftText: "Login",
                            rightText: "Sign up",
                            isLeft: _showLogin,
                            onTapLeft: () => setState(() => _showLogin = true),
                            onTapRight: () => setState(() => _showLogin = false),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 420),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) {
                                final begin = _showLogin
                                    ? const Offset(-0.14, 0)
                                    : const Offset(0.14, 0);
                                final offsetAnim = Tween<Offset>(
                                  begin: begin,
                                  end: Offset.zero,
                                ).animate(anim);
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(position: offsetAnim, child: child),
                                );
                              },
                              child: _showLogin ? _buildLogin(isIOS) : _buildSignup(isIOS),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildLogin(bool isIOS) {
    return SingleChildScrollView(
      key: const ValueKey("login"),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            _GlassField(
              label: "Email",
              icon: Icons.mail_outline_rounded,
              controller: _email,
              validator: (v) => (v == null || v.trim().isEmpty) ? "Enter email" : null,
              theme: FieldTheme.light,
            ),
            const SizedBox(height: 12),
            _GlassField(
              label: "Password",
              icon: Icons.lock_outline_rounded,
              controller: _password,
              obscure: !_showPw,
              suffix: IconButton(
                icon: Icon(
                  _showPw ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF5B5F5F),
                ),
                onPressed: () => setState(() => _showPw = !_showPw),
              ),
              validator: (v) => (v == null || v.isEmpty) ? "Enter password" : null,
              theme: FieldTheme.light,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text(
                  "Forgot password?",
                  style: TextStyle(fontWeight: FontWeight.w800, color: primary),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _LiquidGlassButton(
              text: "Login",
              loading: _loading,
              onTap: _loading ? null : _loginEmail,
              variant: ButtonVariant.primary,
            ),
            const SizedBox(height: 14),
            const _OrDivider(),
            const SizedBox(height: 14),
            _LiquidGlassButton(
              text: "Continue with Google",
              loading: false,
              onTap: _loading ? null : _loginGoogle,
              variant: ButtonVariant.surface,
              leadingAsset: "assets/images/google.png.png",
            ),
            const SizedBox(height: 10),
            if (isIOS)
              _LiquidGlassButton(
                text: "Continue with Apple",
                loading: false,
                onTap: _loading ? null : _loginApple,
                variant: ButtonVariant.surface,
                leadingAsset: "assets/images/apple.png.webp",
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignup(bool isIOS) {
    return SingleChildScrollView(
      key: const ValueKey("signup"),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _GlassField(
              label: "Full name",
              icon: Icons.person_outline_rounded,
              controller: _nameR,
              validator: (v) => (v == null || v.trim().isEmpty) ? "Enter name" : null,
              theme: FieldTheme.greyLabelOnBlue, // ✅ labels grey on blue
            ),
            const SizedBox(height: 12),
            _GlassField(
              label: "Email",
              icon: Icons.mail_outline_rounded,
              controller: _emailR,
              validator: (v) => (v == null || v.trim().isEmpty) ? "Enter email" : null,
              theme: FieldTheme.greyLabelOnBlue, // ✅ labels grey on blue
            ),
            const SizedBox(height: 12),
            _GlassField(
              label: "Password",
              icon: Icons.lock_outline_rounded,
              controller: _passR,
              obscure: !_showPwR,
              suffix: IconButton(
                icon: Icon(
                  _showPwR ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF5B5F5F),
                ),
                onPressed: () => setState(() => _showPwR = !_showPwR),
              ),
              validator: (v) => (v == null || v.length < 6) ? "Password must be 6+ chars" : null,
              theme: FieldTheme.greyLabelOnBlue, // ✅ labels grey on blue
            ),
            const SizedBox(height: 12),
            _GlassField(
              label: "Confirm password",
              icon: Icons.lock_outline_rounded,
              controller: _confirmR,
              obscure: !_showPwC,
              suffix: IconButton(
                icon: Icon(
                  _showPwC ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF5B5F5F),
                ),
                onPressed: () => setState(() => _showPwC = !_showPwC),
              ),
              validator: (v) => (v != _passR.text) ? "Passwords do not match" : null,
              theme: FieldTheme.greyLabelOnBlue, // ✅ labels grey on blue
            ),
            const SizedBox(height: 16),
            _LiquidGlassButton(
              text: "Create account",
              loading: _loading,
              onTap: _loading ? null : _registerEmail,
              variant: ButtonVariant.onBlue,
            ),
            const SizedBox(height: 14),
            const _OrDivider(onBlue: true),
            const SizedBox(height: 14),
            _LiquidGlassButton(
              text: "Continue with Google",
              loading: false,
              onTap: _loading ? null : _loginGoogle,
              variant: ButtonVariant.surface,
              leadingAsset: "assets/images/google.png.png",
            ),
            const SizedBox(height: 10),
            if (isIOS)
              _LiquidGlassButton(
                text: "Continue with Apple",
                loading: false,
                onTap: _loading ? null : _loginApple,
                variant: ButtonVariant.onBlueSurface,
                leadingAsset: "assets/images/apple.png.webp",
              ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- UI ---------------- */

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.onWhite});
  final bool onWhite;

  static const Color bgBlue = Color(0xFF3B7691);

  @override
  Widget build(BuildContext context) {
    final titleColor = onWhite ? bgBlue : Colors.white;
    final subColor = onWhite ? bgBlue.withOpacity(0.75) : Colors.white.withOpacity(0.82);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Image.asset('assets/images/logo2.png', height: 98),
          const SizedBox(height: 10),
          Text(
            "Ratq",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Wound Monitoring App",
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel: white glass for login, blue liquid glass for signup
class _SlidingAuthCard extends StatelessWidget {
  const _SlidingAuthCard({
    required this.showLogin,
    required this.child,
  });

  final bool showLogin;
  final Widget child;

  static const Color primary = Color(0xFF3B7691);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 12)),
            ],
            color: showLogin ? Colors.white.withOpacity(0.88) : Colors.white.withOpacity(0.18),
            gradient: showLogin
                ? null
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withOpacity(0.95),
                const Color(0xFF2E8BC0).withOpacity(0.90),
                const Color(0xFF6FE7FF).withOpacity(0.45),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuthSwitchLiquid extends StatelessWidget {
  const _AuthSwitchLiquid({
    required this.leftText,
    required this.rightText,
    required this.isLeft,
    required this.onTapLeft,
    required this.onTapRight,
  });

  final String leftText;
  final String rightText;
  final bool isLeft;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;

  static const Color primary = Color(0xFF3B7691);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: (MediaQuery.of(context).size.width - 16 * 2 - 18 * 2) / 2,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primary.withOpacity(0.25),
                        primary.withOpacity(0.18),
                        Colors.white.withOpacity(0.10),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTapLeft,
                      borderRadius: BorderRadius.circular(999),
                      child: Center(
                        child: Text(
                          leftText,
                          style: TextStyle(
                            color: isLeft ? primary : const Color(0xFF64748B),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: onTapRight,
                      borderRadius: BorderRadius.circular(999),
                      child: Center(
                        child: Text(
                          rightText,
                          style: TextStyle(
                            color: !isLeft ? primary : const Color(0xFF64748B),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ UPDATED: added greyLabelOnBlue
enum FieldTheme { light, darkOnBlue, greyLabelOnBlue }

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.label,
    required this.icon,
    required this.controller,
    this.validator,
    this.obscure = false,
    this.suffix,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final Widget? suffix;
  final FieldTheme theme;

  @override
  Widget build(BuildContext context) {
    final onBlue = theme != FieldTheme.light;

    final fill = onBlue ? Colors.white.withOpacity(0.14) : const Color(0xFFF2F4F5);
    final textColor = onBlue ? Colors.white : const Color(0xFF111827);

    // ✅ labels grey when theme is greyLabelOnBlue
    final labelColor = theme == FieldTheme.greyLabelOnBlue
        ? const Color(0xFF5B5F5F)
        : onBlue
        ? Colors.white.withOpacity(0.85)
        : const Color(0xFF5B5F5F);

    // ✅ icons grey when theme is greyLabelOnBlue
    final iconColor = theme == FieldTheme.greyLabelOnBlue
        ? const Color(0xFF5B5F5F)
        : onBlue
        ? Colors.white.withOpacity(0.9)
        : const Color(0xFF5B5F5F);

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: iconColor),
        suffixIcon: suffix,
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

enum ButtonVariant { primary, surface, onBlue, onBlueSurface }

class _LiquidGlassButton extends StatelessWidget {
  const _LiquidGlassButton({
    required this.text,
    required this.loading,
    required this.onTap,
    required this.variant,
    this.leadingAsset,
  });

  final String text;
  final bool loading;
  final VoidCallback? onTap;
  final ButtonVariant variant;
  final String? leadingAsset;

  static const Color primary = Color(0xFF3B7691);

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    final isSurface = variant == ButtonVariant.surface || variant == ButtonVariant.onBlueSurface;
    final onBlue = variant == ButtonVariant.onBlue || variant == ButtonVariant.onBlueSurface;

    final textColor = isSurface ? (onBlue ? Colors.white : const Color(0xFF111827)) : Colors.white;
    final border = Colors.white.withOpacity(onBlue ? 0.45 : 0.55);

    final gradient = isSurface
        ? LinearGradient(
      colors: onBlue
          ? [Colors.white.withOpacity(0.20), Colors.white.withOpacity(0.12)]
          : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.72)],
    )
        : LinearGradient(
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
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 10)),
              ],
              gradient: gradient,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leadingAsset != null) ...[
                    Image.asset(leadingAsset!, height: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({this.onBlue = false});
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final line = onBlue ? Colors.white.withOpacity(0.28) : const Color(0x11000000);
    final txt = onBlue ? Colors.white.withOpacity(0.85) : const Color(0xFF6B7280);

    return Row(
      children: [
        Expanded(child: Container(height: 1, color: line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text("or", style: TextStyle(fontWeight: FontWeight.w800, color: txt)),
        ),
        Expanded(child: Container(height: 1, color: line)),
      ],
    );
  }
}
