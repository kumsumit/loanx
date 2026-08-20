import 'package:flutter/material.dart';

/// Our custom fork of https://pub.dev/packages/modal_progress_hud adding a fading effect
///
/// wrapper around any widget that makes an async call to show a modal progress
/// indicator while the async call is in progress.
///
/// The progress indicator can be turned on or off using [isLoading]
///
/// The progress indicator defaults to a [CircularProgressIndicator] but can be
/// any kind of widget
///
/// The color of the modal barrier can be set using [color]
///
/// The opacity of the modal barrier can be set using color.withOpacity(0.5)
///
/// HUD=Heads Up Display
///
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Color? color;
  final Widget? progressIndicator;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.progressIndicator,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: color ?? colors.scrim.withValues(alpha: 0.48),
                child: Center(
                  child:
                      progressIndicator ??
                      CircularProgressIndicator(color: colors.primaryContainer),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
