import 'package:flutter/material.dart';

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

  // Inset for rows + dividers (same value => perfectly aligned)
  static const double _inset = 16;

  bool allowNotifications = true;

  BannerStyle bannerStyle = BannerStyle.temporary;

  bool sounds = true;
  bool badges = true;

  ShowPreviews showPreviews = ShowPreviews.always;
  NotificationGrouping grouping = NotificationGrouping.automatic;

  void _saveAndClose() => Navigator.pop(context, true);

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
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
              onChanged: (v) => setState(() => allowNotifications = v),
            ),
          ),

          const SizedBox(height: 18),
          _sectionLabel("ALERTS"),

          _card(
            child: Column(
              children: [
                // ✅ NO divider at the top of the card
                _chevronRow(
                  title: "Banner Style",
                  valueText: bannerStyle == BannerStyle.temporary
                      ? "Temporary"
                      : "Persistent",
                  enabled: allowNotifications,
                  onTap: () async {
                    if (!allowNotifications) return;
                    final result = await _pickBannerStyle();
                    if (result != null) setState(() => bannerStyle = result);
                  },
                ),

                // ✅ Divider only BETWEEN rows (Banner Style <-> Sounds)
                _insetDivider(),

                _switchRow(
                  title: "Sounds",
                  value: sounds,
                  enabled: allowNotifications,
                  onChanged: (v) => setState(() => sounds = v),
                ),

                // ✅ Divider aligned & inset (Sounds <-> Badges)
                _insetDivider(),

                _switchRow(
                  title: "Badges",
                  value: badges,
                  enabled: allowNotifications,
                  onChanged: (v) => setState(() => badges = v),
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
                    if (result != null) setState(() => showPreviews = result);
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
                    if (result != null) setState(() => grouping = result);
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

  // ✅ Inset divider: same left/right inset as rows, so it lines up perfectly
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
            // circle (thumb)
            thumbColor: WidgetStateProperty.all(Colors.white),

            // background track
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return primaryColor; // ON → blue
              }
              return Colors.grey.shade300; // OFF → light grey
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
  Future<BannerStyle?> _pickBannerStyle() async {
    return showModalBottomSheet<BannerStyle>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _pickerSheet(
        title: "Banner Style",
        options: const {
          "Temporary": BannerStyle.temporary,
          "Persistent": BannerStyle.persistent,
        },
      ),
    );
  }

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
                title: Text(
                  e.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
}

enum BannerStyle { temporary, persistent }
enum ShowPreviews { always, whenUnlocked, never }
enum NotificationGrouping { automatic, byApp, off }