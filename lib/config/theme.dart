import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF0071E3);
  static const Color primaryBlack = Color(0xFF1D1D1F);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFE53E3E);
  static const Color info = Color(0xFF0284C7);

  // Status Tag Colors
  static const Color statusNew = Color(0xFFE0F2FE);
  static const Color statusNewText = Color(0xFF0284C7);
  static const Color statusPreparing = Color(0xFFFEF3C7);
  static const Color statusPreparingText = Color(0xFF92400E);
  static const Color statusReady = Color(0xFFD1FAE5);
  static const Color statusReadyText = Color(0xFF065F46);
  static const Color statusDelivery = Color(0xFFE0E7FF);
  static const Color statusDeliveryText = Color(0xFF4338CA);
  static const Color statusCompleted = Color(0xFFF3F4F6);
  static const Color statusCompletedText = Color(0xFF4B5563);

  // Background Colors
  static const Color background = Color(0xFFF5F5F7);
  static const Color cardBackground = Colors.white;
  static const Color inputBackground = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Border Colors
  static const Color border = Color(0xFFD2D2D7);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Role Colors
  static const Color ownerColor = Color(0xFF6366F1);
  static const Color developerColor = Color(0xFFE53E3E);
  static const Color kitchenColor = Color(0xFFF59E0B);
  static const Color deliveryColor = Color(0xFF10B981);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0071E3), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        surface: cardBackground,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        shadowColor: Colors.black12,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: const Color(0xFFE2E8F0),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: GoogleFonts.inter(fontSize: 16, color: textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE2E8F0),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Helper methods for status colors
  static Color getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return statusNew;
      case 'preparing':
        return statusPreparing;
      case 'ready_for_pickup':
        return statusReady;
      case 'out_for_delivery':
        return statusDelivery;
      case 'completed':
        return statusCompleted;
      default:
        return statusNew;
    }
  }

  static Color getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return statusNewText;
      case 'preparing':
        return statusPreparingText;
      case 'ready_for_pickup':
        return statusReadyText;
      case 'out_for_delivery':
        return statusDeliveryText;
      case 'completed':
        return statusCompletedText;
      default:
        return statusNewText;
    }
  }

  static String getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'preparing':
        return 'Preparing';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
