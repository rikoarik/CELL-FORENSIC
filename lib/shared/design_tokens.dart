import 'package:flutter/material.dart';

/// Shared visual tokens for mobile + Flutter Web dashboard (E1-03).
abstract final class DesignTokens {
  static const Color navy = Color(0xFF102A43);
  static const Color blue = Color(0xFF1363DF);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color inkMuted = Color(0xFF334E68);
  static const Color border = Color(0xFFD9E2EC);

  static const double radiusCard = 20;
  static const double radiusButton = 14;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 40;

  static const double touchMin = 48;
  static const double dashboardSidebar = 240;
  static const double dashboardBreakpoint = 900;
}
