import 'package:flutter/material.dart';

/// Keeps the native application on the same mobile design canvas as the web
/// build, even when Android's "Screen zoom" or large font setting reduces the
/// number of logical pixels Flutter receives.
///
/// The reference UI is authored at 430 logical pixels wide. On a narrower
/// native viewport we lay the app out at that width and uniformly fit it back
/// into the real screen. This preserves card proportions, spacing and type
/// hierarchy instead of allowing fixed-size controls to become oversized.
class AppDesignViewport extends StatelessWidget {
  const AppDesignViewport({super.key, required this.child});

  static const double designWidth = 430;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final actual = MediaQuery.of(context);

    // The web reference uses the authored type sizes. Do the same in the APK
    // instead of allowing Android font scaling to independently enlarge text
    // and break the surrounding card geometry.
    final stableTypography = actual.copyWith(textScaler: TextScaler.noScaling);
    // Android can briefly report a zero-sized surface while the activity is
    // attaching. Dividing the insets and height by a zero scale produces
    // infinite layout constraints and leaves the Flutter surface blank. Let
    // the child participate in that harmless first layout; MediaQuery rebuilds
    // this widget with the real dimensions as soon as the surface is ready.
    if (actual.size.width <= 0 || actual.size.height <= 0) {
      return MediaQuery(data: stableTypography, child: child);
    }

    final scale = (actual.size.width / designWidth).clamp(0.01, 1.0);
    if (scale >= 1) {
      return MediaQuery(data: stableTypography, child: child);
    }

    EdgeInsets rescale(EdgeInsets value) => EdgeInsets.fromLTRB(
      value.left / scale,
      value.top / scale,
      value.right / scale,
      value.bottom / scale,
    );

    final designMedia = stableTypography.copyWith(
      size: Size(designWidth, actual.size.height / scale),
      padding: rescale(actual.padding),
      viewPadding: rescale(actual.viewPadding),
      viewInsets: rescale(actual.viewInsets),
      systemGestureInsets: rescale(actual.systemGestureInsets),
    );

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: designWidth,
          height: actual.size.height / scale,
          child: MediaQuery(data: designMedia, child: child),
        ),
      ),
    );
  }
}
