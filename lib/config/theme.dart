import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  
  // Primary Brand Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryOrange = Color(0xFFFC8019);
  static const Color primaryRed = Color(0xFFE23744);
  static const Color primaryBlack = Color(0xFF1D1D1F);

  // Payment/Transaction Blue Theme (Trust & Security)
  static const Color paymentBlue = Color(0xFF2563EB);
  static const Color paymentBlueDark = Color(0xFF1D4ED8);
  static const Color paymentBlueLight = Color(0xFF3B82F6);
  static const Color paymentBlueBg = Color(0xFFEFF6FF);
  
  // Accent Colors (Food-inspired warmth)
  static const Color accentOrange = Color(0xFFFC8019);
  static const Color accentYellow = Color(0xFFFBBF24);
  static const Color accentCoral = Color(0xFFF97316);
  
  // Legacy alias
  static const Color primaryGreen = success;

  // Status Colors (Modern vibrant)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Status Tag Colors
  static const Color statusNew = Color(0xFFDCFCE7);
  static const Color statusNewText = Color(0xFF16A34A);
  static const Color statusPreparing = Color(0xFFFEF3C7);
  static const Color statusPreparingText = Color(0xFFD97706);
  static const Color statusReady = Color(0xFFD1FAE5);
  static const Color statusReadyText = Color(0xFF065F46);
  static const Color statusDelivery = Color(0xFFDBEAFE);
  static const Color statusDeliveryText = Color(0xFF2563EB);
  static const Color statusCompleted = Color(0xFFF3F4F6);
  static const Color statusCompletedText = Color(0xFF4B5563);

  // Background Colors (Clean & Modern)
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;
  static const Color inputBackground = Colors.white;
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Border Colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderColor = border;
  static const Color borderLight = Color(0xFFF3F4F6);

  // Role Colors (Distinct for each user type)
  static const Color ownerColor = Color(0xFF6366F1);
  static const Color developerColor = Color(0xFFE11D48);
  static const Color kitchenColor = Color(0xFFEA580C);
  static const Color deliveryColor = Color(0xFF059669);

  // ============ GRADIENTS ============
  
  // Payment/Trust Gradient (Blue)
  static const LinearGradient paymentGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Primary Action Gradient (Orange - Swiggy style)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFC8019), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Success Gradient
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Premium Dark Gradient
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1F2937), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
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
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange, // Swiggy-style orange for primary actions
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryOrange, // Swiggy-style orange
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF3F4F6),
        selectedColor: primaryOrange.withOpacity(0.15),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
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
