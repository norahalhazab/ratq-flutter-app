import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 && 
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(8);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  static double getFontSize(BuildContext context, {double mobile = 14, double tablet = 16, double desktop = 18}) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  static double getIconSize(BuildContext context, {double mobile = 16, double tablet = 20, double desktop = 24}) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  static double getAvatarRadius(BuildContext context, {double mobile = 16, double tablet = 20, double desktop = 24}) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  static double getImageHeight(BuildContext context, {double mobile = 120, double tablet = 200, double desktop = 250}) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  static BorderRadius getBorderRadius(BuildContext context, {double mobile = 8, double tablet = 12, double desktop = 16}) {
    final radius = isMobile(context) ? mobile : isTablet(context) ? tablet : desktop;
    return BorderRadius.circular(radius);
  }

  static EdgeInsets getButtonPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    } else {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    }
  }

  static double getSpacing(BuildContext context, {double mobile = 4, double tablet = 8, double desktop = 12}) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }
} 