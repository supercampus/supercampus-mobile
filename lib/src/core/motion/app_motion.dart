import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const deliberate = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;

  static const pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: _AppPageTransitionsBuilder(),
      TargetPlatform.iOS: _AppPageTransitionsBuilder(),
      TargetPlatform.macOS: _AppPageTransitionsBuilder(),
      TargetPlatform.windows: _AppPageTransitionsBuilder(),
      TargetPlatform.linux: _AppPageTransitionsBuilder(),
      TargetPlatform.fuchsia: _AppPageTransitionsBuilder(),
    },
  );

  static Widget switchTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.018, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst ||
        MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return child;
    }
    return AppMotion.switchTransition(child, animation);
  }
}
