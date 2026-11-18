import 'package:flutter/material.dart';

import 'theme.dart';

/// Keeps every screen in a phone-width portrait column, on Linux too.
///
/// On a phone the column fills the screen; on a wide desktop window the
/// remaining space becomes a backdrop around the phone-shaped canvas.
class PhoneViewport extends StatelessWidget {
  const PhoneViewport({super.key, required this.child});

  static const double maxWidth = 400;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MoonpetalColors.viewportBackdrop,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}
