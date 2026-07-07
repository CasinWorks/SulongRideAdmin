import 'package:flutter/material.dart';

/// Forest / eco palette — matches [etrike_ph_user] (EcoRide / Sulong Ride rider app).
abstract final class AppColors {
  static const Color forestDark = Color(0xFF0B2114);
  static const Color forestMedium = Color(0xFF123321);
  static const Color forestLight = Color(0xFF1B452F);
  static const Color ecoGreen = Color(0xFF4FA24A);
  static const Color ecoGreenLight = Color(0xFF5EB759);
  static const Color ecoCream = Color(0xFFFBF9F4);
  static const Color ecoCreamDark = Color(0xFFE2DDD5);

  static const Color mapBg = Color(0xFF08170F);
  static const Color pickupPin = Color(0xFF10B981);
  static const Color dropoffPin = Color(0xFFEF4444);
  static const Color amber = Color(0xFFFBBF24);
  static const Color indigo = Color(0xFF818CF8);
  static const Color rose = Color(0xFFFB7185);
  static const Color error = Color(0xFFF87171);

  // Semantic aliases used across the app.
  static const Color primary = forestDark;
  static const Color accent = ecoGreen;
  static const Color background = forestDark;
  static const Color surface = forestMedium;
  static const Color textPrimary = ecoCream;
  static const Color textSecondary = ecoCreamDark;
  static const Color divider = forestLight;

  static const Color drawerShadow = Color(0x6608170F);
}
