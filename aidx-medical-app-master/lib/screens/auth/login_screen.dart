import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/screens/dashboard_screen.dart';
import 'package:aidx/screens/Homepage.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isRegPasswordVisible = false;
  bool _isRegConfirmVisible = false;

  static  Color bgColor = const Color(0xFFAFCBE8);
  static const Color fieldTextColor = Color(0xFF5B5F5F);
  static const Color fieldFillColor = Color(0xFFF2F4F5); // رمادي فاتح جدًا

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: fieldTextColor),
      prefixIcon: Icon(icon, color: fieldTextColor),
      suffixIcon: suffix,
      filled: true,
      fillColor: fieldFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      final user = await auth.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Homepage()),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      await auth.registerWithEmailAndPassword(
        _regEmailController.text.trim(),
        _regPasswordController.text.trim(),
        _regNameController.text.trim(),
      );

      if (mounted) {
        _tabController.animateTo(0);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            /// LOGO
            Image.asset(
              'assets/images/logo2.png',
              height: 120,
            ),

            const SizedBox(height: 16),

            const Text(
              'Ratq',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Wound Monitoring App',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 30),

            /// CARD
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: bgColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: bgColor,
                      tabs: const [
                        Tab(text: 'Login'),
                        Tab(text: 'Sign up'),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          /// LOGIN
                          Form(
                            key: _loginFormKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  style:
                                  const TextStyle(color: fieldTextColor),
                                  decoration: _inputDecoration(
                                    label: 'Email',
                                    icon: FeatherIcons.mail,
                                  ),
                                  validator: (v) =>
                                  v!.isEmpty ? 'Enter email' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  style:
                                  const TextStyle(color: fieldTextColor),
                                  decoration: _inputDecoration(
                                    label: 'Password',
                                    icon: FeatherIcons.lock,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? FeatherIcons.eye
                                            : FeatherIcons.eyeOff,
                                        color: fieldTextColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                          !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (v) =>
                                  v!.isEmpty ? 'Enter password' : null,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bgColor,
                                    minimumSize:
                                    const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                      : const Text(
                                    'Login',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// SIGN UP
                          Form(
                            key: _registerFormKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _regNameController,
                                  style:
                                  const TextStyle(color: fieldTextColor),
                                  decoration: _inputDecoration(
                                    label: 'Full name',
                                    icon: FeatherIcons.user,
                                  ),
                                  validator: (v) =>
                                  v!.isEmpty ? 'Enter name' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _regEmailController,
                                  style:
                                  const TextStyle(color: fieldTextColor),
                                  decoration: _inputDecoration(
                                    label: 'Email',
                                    icon: FeatherIcons.mail,
                                  ),
                                  validator: (v) =>
                                  v!.isEmpty ? 'Enter email' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _regPasswordController,
                                  obscureText: !_isRegPasswordVisible,
                                  style:
                                  const TextStyle(color: fieldTextColor),
                                  decoration: _inputDecoration(
                                    label: 'Password',
                                    icon: FeatherIcons.lock,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _isRegPasswordVisible
                                            ? FeatherIcons.eye
                                            : FeatherIcons.eyeOff,
                                        color: fieldTextColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isRegPasswordVisible =
                                          !_isRegPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (v) =>
                                  v!.length < 6 ? 'Weak password' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _regConfirmController,
                                  obscureText: !_isRegConfirmVisible,
                                  style:
                                  const TextStyle(color: fieldTextColor),
                                  decoration: _inputDecoration(
                                    label: 'Confirm password',
                                    icon: FeatherIcons.lock,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _isRegConfirmVisible
                                            ? FeatherIcons.eye
                                            : FeatherIcons.eyeOff,
                                        color: fieldTextColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isRegConfirmVisible =
                                          !_isRegConfirmVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (v) => v !=
                                      _regPasswordController.text
                                      ? 'Passwords do not match'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bgColor,
                                    minimumSize:
                                    const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Sign up',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
