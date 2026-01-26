import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/theme.dart';

/// Reusable premium dark theme components for consistent UI across the app
class PremiumTheme {
  // Background gradient
  static BoxDecoration get backgroundGradient => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F2027),
            const Color(0xFF203A43),
            const Color(0xFF2C5364),
          ],
        ),
      );

  // Glass card decoration
  static BoxDecoration glassCard({
    double borderRadius = 24,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.1),
        ),
      );

  // Premium header with back button and title
  static Widget buildHeader({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontFamily: 'Montserrat',
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // Section header with icon
  static Widget buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    );
  }

  // Premium input field
  static InputDecoration inputDecoration({
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.3),
        fontFamily: 'Montserrat',
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.white.withOpacity(0.5), size: 20)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  // Premium button
  static Widget buildButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.accentColor],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Glass blur overlay
  static Widget glassBlur({required Widget child}) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: child,
    );
  }
}
