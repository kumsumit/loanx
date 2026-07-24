import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

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
class LoadingOverlay extends HookWidget {
  final bool isLoading;
  final Color? color;
  final Widget progressIndicator;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.progressIndicator = const CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    ),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 300),
    );
    final animation = useMemoized(
      () => Tween(begin: 0.0, end: 1.0).animate(controller),
    );

    useEffect(() {
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.forward) {
          controller.forward();
        } else if (status == AnimationStatus.dismissed) {
          controller.reverse();
        }
      }

      animation.addStatusListener(listener);

      if (isLoading) {
        controller.forward();
      } else {
        controller.reverse();
      }
      return;
    }, [isLoading]);

    var widgets = <Widget>[];
    widgets.add(child);

    if (controller.isAnimating || controller.value != 0.0) {
      final modal = FadeTransition(
        opacity: animation,
        child: Stack(
          children: <Widget>[
            SizedBox.expand(
              child: ColoredBox(
                color: color ?? Colors.black.withValues(alpha: 0.5),
              ),
            ),
            Center(child: progressIndicator),
          ],
        ),
      );
      widgets.add(modal);
    }

    return Stack(children: widgets);
  }
}
