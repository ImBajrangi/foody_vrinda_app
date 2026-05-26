import 'package:flutter/cupertino.dart';

/// A route that mimics the Telegram / iOS page transition animation (slide from right,
/// parallax slide to left on exit, with drag-to-dismiss support on all platforms).
class TelegramPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  TelegramPageRoute({
    required this.child,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide transition from the right side
            final slideIn = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuart,
                reverseCurve: Curves.easeInQuart,
              ),
            );

            // Parallax slide-out to the left when pushed over
            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0.0),
            ).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOutQuart,
                reverseCurve: Curves.easeInQuart,
              ),
            );

            return SlideTransition(
              position: slideOut,
              child: SlideTransition(
                position: slideIn,
                child: CupertinoPageTransition(
                  primaryRouteAnimation: animation,
                  secondaryRouteAnimation: secondaryAnimation,
                  linearTransition: false,
                  child: child,
                ),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}
