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

  ShowPreviews showPreviews = ShowPreviews.always;
  NotificationGrouping grouping = NotificationGrouping.automatic;

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

    // optional (if you want to persist these too later)
    final previewsStr = prefs.getString('notif_show_previews');
    final groupingStr = prefs.getString('notif_grouping');

    if (!mounted) return;
    setState(() {
      allowNotifications = allow;
      sounds = snd;
      badges = bdg;

      showPreviews = _showPreviewsFromString(previewsStr) ?? ShowPreviews.always;
      grouping = _groupingFromString(groupingStr) ??
          NotificationGrouping.automatic;

      _loadingPrefs = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_notifications', allowNotifications);
    await prefs.setBool('notif_sounds', sounds);
    await prefs.setBool('notif_badges', badges);

    // persist these too (optional but useful)
    await prefs.setString('notif_show_previews', showPreviews.name);
    await prefs.setString('notif_grouping', grouping.name);
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
        title: const Text("Notifications"),
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            "Cancel",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
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

          const SizedBox(height: 18),
          _sectionLabel("LOCK SCREEN APPEARANCE"),

          _card(
            child: Column(
              children: [
                _chevronRow(
                  title: "Show Previews",
                  valueText: _showPreviewsText(showPreviews),
                  enabled: allowNotifications,
                  onTap: () async {
                    if (!allowNotifications) return;
                    final result = await _pickShowPreviews();
                    if (result != null) {
                      setState(() => showPreviews = result);
                      await _savePrefs();
                    }
                  },
                ),
                _insetDivider(),
                _chevronRow(
                  title: "Notification Grouping",
                  valueText: _groupingText(grouping),
                  enabled: allowNotifications,
                  onTap: () async {
                    if (!allowNotifications) return;
                    final result = await _pickGrouping();
                    if (result != null) {
                      setState(() => grouping = result);
                      await _savePrefs();
                    }
                  },
                ),
              ],
            ),
          ),

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
          fontSize: 12,
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

  Widget _chevronRow({
    required String title,
    required String valueText,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
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
            Text(
              valueText,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textMuted.withOpacity(enabled ? 1 : 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: textMuted.withOpacity(enabled ? 1 : 0.6),
            ),
          ],
        ),
      ),
    );
  }

  // ================= Pickers =================

  Future<ShowPreviews?> _pickShowPreviews() async {
    return showModalBottomSheet<ShowPreviews>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _pickerSheet(
        title: "Show Previews",
        options: const {
          "Always (Default)": ShowPreviews.always,
          "When Unlocked": ShowPreviews.whenUnlocked,
          "Never": ShowPreviews.never,
        },
      ),
    );
  }

  Future<NotificationGrouping?> _pickGrouping() async {
    return showModalBottomSheet<NotificationGrouping>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _pickerSheet(
        title: "Notification Grouping",
        options: const {
          "Automatic": NotificationGrouping.automatic,
          "By App": NotificationGrouping.byApp,
          "Off": NotificationGrouping.off,
        },
      ),
    );
  }

  Widget _pickerSheet<T>({
    required String title,
    required Map<String, T> options,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.10),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...options.entries.map(
                  (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, e.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _showPreviewsText(ShowPreviews v) {
    switch (v) {
      case ShowPreviews.always:
        return "Always (Default)";
      case ShowPreviews.whenUnlocked:
        return "When Unlocked";
      case ShowPreviews.never:
        return "Never";
    }
  }

  String _groupingText(NotificationGrouping v) {
    switch (v) {
      case NotificationGrouping.automatic:
        return "Automatic";
      case NotificationGrouping.byApp:
        return "By App";
      case NotificationGrouping.off:
        return "Off";
    }
  }

  // ================= String <-> Enum (prefs) =================

  ShowPreviews? _showPreviewsFromString(String? s) {
    if (s == null) return null;
    for (final v in ShowPreviews.values) {
      if (v.name == s) return v;
    }
    return null;
  }

  NotificationGrouping? _groupingFromString(String? s) {
    if (s == null) return null;
    for (final v in NotificationGrouping.values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

enum ShowPreviews { always, whenUnlocked, never }
enum NotificationGrouping { automatic, byApp, off }