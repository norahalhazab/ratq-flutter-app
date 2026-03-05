import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bottom_nav.dart';
import '../services/smart_watch_simulator_service.dart';

class SmartWatchSimulatorScreen extends StatefulWidget {
  const SmartWatchSimulatorScreen({super.key});

  @override
  State<SmartWatchSimulatorScreen> createState() =>
      _SmartWatchSimulatorScreenState();
}

class _SmartWatchSimulatorScreenState extends State<SmartWatchSimulatorScreen> {
  final service = SmartWatchSimulatorService.instance;

  @override
  void initState() {
    super.initState();

    // ✅ Auto-connect as soon as this screen opens
    // (won't re-connect if your service already handles that internally)
    service.connect();

    service.vitalsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final hr = service.heartRate;
    final bp = service.bloodPressure;
    final connected = service.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Smart Watch",
          style: GoogleFonts.dmSans(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              _WatchMock(
                heartRate: hr,
                bloodPressure: bp,
              ),

              const Spacer(),

              // ✅ Connect / Connected button (same colors, never "disabled" so it won't dim)
              SizedBox(
                width: double.infinity,
                height: 58,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    // ✅ Keep the SAME light gradient like before (no dark/disabled look)
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3B7691),
                        Color(0xFF5FA3BC),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    // ✅ Keep it enabled; if connected do nothing
                    onPressed: () {
                      if (!connected) service.connect();
                    },
                    icon: Icon(
                      connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      color: Colors.white,
                    ),
                    label: Text(
                      connected ? "Connected" : "Connect",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchMock extends StatelessWidget {
  const _WatchMock({
    required this.heartRate,
    required this.bloodPressure,
  });

  final int heartRate;
  final String bloodPressure;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -6,
            top: 140,
            child: _CrownButton(),
          ),
          Positioned(
            right: -4,
            top: 210,
            child: _SideButton(),
          ),

          Container(
            width: 270,
            height: 340,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(56),
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  blurRadius: 32,
                  spreadRadius: 8,
                  color: Colors.black.withOpacity(0.35),
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D0D0D),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.07),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$hh:$mm",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _MetricLine(
                        icon: Icons.favorite,
                        iconColor: Colors.redAccent,
                        label: "HR",
                        value: "$heartRate bpm",
                      ),
                      const SizedBox(height: 8),

                      _MetricLine(
                        icon: Icons.monitor_heart,
                        iconColor: Colors.greenAccent,
                        label: "BP",
                        value: bloodPressure,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CrownButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}