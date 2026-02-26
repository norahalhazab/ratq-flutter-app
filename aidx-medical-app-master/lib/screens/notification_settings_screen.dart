// notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // ===== Colors (from your theme) =====
  static const Color primaryColor = Color(0xFF3B7691);
  static const Color bgLight = Color(0xFFF6F8FB);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF475569);
  static const Color white = Colors.white;

  static const double _inset = 16;

  bool allowNotifications = true;
  bool sounds = true;
  bool badges = true;

  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final allow = prefs.getBool('allow_notifications') ?? true;
    final snd = prefs.getBool('notif_sounds') ?? true;
    final bdg = prefs.getBool('notif_badges') ?? true;

    if (!mounted) return;
    setState(() {
      allowNotifications = allow;
      sounds = snd;
      badges = bdg;
      _loadingPrefs = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_notifications', allowNotifications);
    await prefs.setBool('notif_sounds', sounds);
    await prefs.setBool('notif_badges', badges);
  }

  Future<void> _saveAndClose() async {
    await _savePrefs();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return const Scaffold(
        backgroundColor: bgLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Notifications",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            "Cancel",
            style: TextStyle( fontSize: 16, color: primaryColor, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        children: [
          _card(
            child: _switchRow(
              title: "Allow Notifications",
              value: allowNotifications,
              onChanged: (v) async {
                setState(() => allowNotifications = v);
                await _savePrefs();
              },
            ),
          ),

          const SizedBox(height: 18),
          _sectionLabel("ALERTS"),

          _card(
            child: Column(
              children: [
                _switchRow(
                  title: "Sounds",
                  value: sounds,
                  enabled: allowNotifications,
                  onChanged: (v) async {
                    setState(() => sounds = v);
                    await _savePrefs();
                  },
                ),
                _insetDivider(),
                _switchRow(
                  title: "Badges",
                  value: badges,
                  enabled: allowNotifications,
                  onChanged: (v) async {
                    setState(() => badges = v);
                    await _savePrefs();
                  },
                ),
              ],
            ),
          ),

          // ✅ Save relocated here (right after Alerts)
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saveAndClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Save",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1F0B0F14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B0F14),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: textMuted.withOpacity(0.8),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _insetDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _inset),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: Colors.black.withOpacity(0.10),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: enabled ? textDark : textMuted.withOpacity(0.6),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return primaryColor;
              return Colors.grey.shade300;
            }),
          ),
        ],
      ),
    );
  }
}