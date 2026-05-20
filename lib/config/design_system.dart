import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// FOODY VRINDA PREMIUM DESIGN SYSTEM
/// "Gourmet & Modern" Glassmorphic Extensions
/// ═══════════════════════════════════════════════════════════════════════════

class FoodyTokens {
  static Brightness brightness = Brightness.light;
  static bool get isDark => brightness == Brightness.dark;

  static void of(BuildContext context) {
    brightness = Theme.of(context).brightness;
  }

  // Brand Accents
  static const Color primaryOrange = AppTheme.primaryOrange;
  static const Color primaryBlue = AppTheme.primaryBlue;
  static const Color primaryRed = AppTheme.primaryRed;
  static const Color charcoalDark = Color(0xFF0F0F15);
  
  // Warm Culinary Palette (HSL Harmonized)
  static Color get accentOrangeLight => const Color(0xFFFF9E59);
  static Color get accentOrangeDark => const Color(0xFFD65C00);
  
  static Color get textPrimary => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textMuted => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color get scaffoldBg => isDark ? charcoalDark : const Color(0xFFF8FAFC);
  static Color get surfaceCard => isDark ? const Color(0xFF1E1E26) : Colors.white;
  static Color get borderSubtle => isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS: Radiant Culinary & Glass
  // ═══════════════════════════════════════════════════════════════════════════
  static const LinearGradient culinaryFlameGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFC8019), Color(0xFFE23744)], // Warm Orange to Red Flame
  );

  static const LinearGradient ambientGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFD97706)], // Golden Amber
  );

  static const LinearGradient premiumDarkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E1E26), Color(0xFF0F0F15)],
  );

  static const LinearGradient liquidGlassRefraction = LinearGradient(
    begin: Alignment(-0.8, -1.0),
    end: Alignment(0.8, 1.0),
    colors: [
      Color(0x1CFFFFFF),
      Color(0x00FFFFFF),
      Color(0x0CFFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.35, 0.65, 1.0],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASSMORPHISM: Elegant Frosted Surfaces
  // ═══════════════════════════════════════════════════════════════════════════
  static BoxDecoration glassDecoration({
    double blur = 12.0,
    double opacity = 0.08,
    double borderRadius = 20.0,
    Color? color,
    Border? border,
  }) {
    return BoxDecoration(
      color: (color ?? (isDark ? Colors.white : Colors.black)).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        width: 1.0,
      ),
    );
  }
}

class FoodyUI {
  /// Frosted glass card overlaying components beautifully
  static Widget glassCard({
    required Widget child,
    double blur = 15.0,
    double borderRadius = 20.0,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: FoodyTokens.glassDecoration(
              blur: blur,
              borderRadius: borderRadius,
              opacity: FoodyTokens.isDark ? 0.08 : 0.65,
              color: FoodyTokens.isDark ? const Color(0xFF1E1E26) : Colors.white,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Shimmer skeleton container for zero-latency loading experience
  static Widget shimmerLoader({
    required double width,
    required double height,
    double borderRadius = 12.0,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: FoodyTokens.isDark ? Colors.white12 : Colors.black12,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
    .animate(onPlay: (controller) => controller.repeat())
    .shimmer(
      duration: 1500.ms,
      color: (FoodyTokens.isDark ? Colors.white24 : Colors.white70).withValues(alpha: 0.25),
    );
  }

  /// Bouncy button interaction
  static Widget bounceClickable({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: child
          .animate(onPlay: (controller) => controller.stop())
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(0.95, 0.95),
            duration: 100.ms,
            curve: Curves.easeOut,
          ),
    );
  }
}
