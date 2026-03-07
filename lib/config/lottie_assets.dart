import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lottie animation URLs and local assets
/// Provides a unified interface for loading both network and local animations
class LottieAssets {
  // Food & Delivery themed animations (Verified)
  static const String cooking =
      'https://assets4.lottiefiles.com/packages/lf20_tll0j4bb.json';
  static const String delivery =
      'https://assets5.lottiefiles.com/packages/lf20_hy4txm7l.json';
  static const String foodDelivery =
      'https://assets2.lottiefiles.com/packages/lf20_UJNc2t.json';

  // Success & Celebration (Verified)
  static const String success =
      'https://assets4.lottiefiles.com/packages/lf20_s2lryxtd.json';
  static const String celebration =
      'https://assets1.lottiefiles.com/packages/lf20_touohxv0.json';
  static const String confetti =
      'https://assets9.lottiefiles.com/packages/lf20_rovf9gzu.json';
  static const String checkmark =
      'https://assets6.lottiefiles.com/packages/lf20_jbrw3hcz.json';
  static const String orderSuccess =
      'https://assets3.lottiefiles.com/packages/lf20_wkaoioa4.json';

  // Loading & Progress (Verified)
  static const String loading =
      'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json';
  static const String foodLoading =
      'https://assets8.lottiefiles.com/packages/lf20_tll0j4bb.json';
  static const String dotsLoading =
      'https://assets2.lottiefiles.com/packages/lf20_usmfx6bp.json';

  // Empty States (Verified)
  static const String emptyCart =
      'https://assets9.lottiefiles.com/packages/lf20_qh5z2fdq.json';
  static const String emptyBox =
      'https://assets1.lottiefiles.com/packages/lf20_wnqlfojb.json';
  static const String noData =
      'https://assets4.lottiefiles.com/packages/lf20_hl5n0bwb.json';
  static const String emptySearch =
      'https://assets10.lottiefiles.com/packages/lf20_wnqlfojb.json';

  // Status & Notifications (Verified)
  static const String newOrder =
      'https://assets7.lottiefiles.com/packages/lf20_zzytbs9a.json';
  static const String preparing =
      'https://assets5.lottiefiles.com/packages/lf20_4kx2q32n.json';
  static const String ready =
      'https://assets2.lottiefiles.com/packages/lf20_wfsunjgd.json';
  static const String outForDelivery =
      'https://assets3.lottiefiles.com/packages/lf20_jmejybvu.json';

  // Fun & Interactive (Verified)
  static const String wave =
      'https://assets5.lottiefiles.com/packages/lf20_V9t630.json';
  static const String star =
      'https://assets3.lottiefiles.com/packages/lf20_obhph3sh.json';
  static const String heart =
      'https://lottie.host/4c1d3dd6-8c5b-4a97-a9ef-f5e0d9c3f4cb/GwWQXXLZJF.json';
  static const String profile =
      'https://assets8.lottiefiles.com/packages/lf20_m6cuL6.json';

  // New Animations (Added 2026-02-01) - Optimized for JSON compatibility
  static const String growingTomatoes =
      'https://assets3.lottiefiles.com/packages/lf20_GKQOcDtWhF.json';
  static const String badCat = 'assets/animations/bad_cat.json';
  static const String deliveryWaiting =
      'https://assets3.lottiefiles.com/packages/lf20_ef929666.json';
  static const String walkingBroccoli =
      'https://assets3.lottiefiles.com/packages/lf20_C9edDzEy7H.json';
  static const String pizzaSlices =
      'https://assets3.lottiefiles.com/packages/lf20_OEskn908sL.json';
  static const String chefPizza =
      'https://assets3.lottiefiles.com/packages/lf20_fdb6df10.json';
  static const String orderStatus =
      'https://assets3.lottiefiles.com/packages/lf20_8Sz3aaaLc0.json';
  static const String deliveryScooter =
      'assets/animations/delivery_scooter.json';
  static const String potato =
      'https://assets3.lottiefiles.com/packages/lf20_pJLA1UHM2k.json';
  static const String pizza =
      'https://assets3.lottiefiles.com/packages/lf20_a56082fa.json';

  // Splash & Welcome (Verified)
  static const String welcome =
      'https://assets10.lottiefiles.com/packages/lf20_V9t630.json';
  static const String foodSplash =
      'https://assets7.lottiefiles.com/packages/lf20_tll0j4bb.json';

  // Error & Warning (Verified)
  static const String error =
      'https://assets4.lottiefiles.com/packages/lf20_qpwbiyxf.json';
  static const String warning =
      'https://lottie.host/5b8a6a1c-3c96-4f90-b9e2-e8cfd50e17e9/K3EWwgoxJN.json';
  static const String notFound =
      'https://assets3.lottiefiles.com/packages/lf20_GIyuXJ.json';

  // Time Period Animations (for schedule selector)
  static const String sunrise =
      'https://assets5.lottiefiles.com/packages/lf20_xlky4kvh.json';
  static const String sun =
      'https://assets3.lottiefiles.com/packages/lf20_kk62um5v.json';
  static const String sunset =
      'https://assets7.lottiefiles.com/packages/lf20_hxeylwwa.json';
  static const String moon =
      'https://assets9.lottiefiles.com/packages/lf20_m4znnezt.json';
  static const String clock =
      'https://assets5.lottiefiles.com/packages/lf20_vPnn3K.json';

  /// Helper to build a Lottie animation from either a URL or an asset path
  static Widget build(
    String source, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    bool repeat = true,
    bool animate = true,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    if (source.startsWith('http')) {
      return Lottie.network(
        source,
        width: width,
        height: height,
        fit: fit,
        repeat: repeat,
        animate: animate,
        errorBuilder: errorBuilder,
      );
    } else {
      return Lottie.asset(
        source,
        width: width,
        height: height,
        fit: fit,
        repeat: repeat,
        animate: animate,
        errorBuilder: errorBuilder,
      );
    }
  }
}
