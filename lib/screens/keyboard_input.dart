import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class KeyboardAwareListView extends HookWidget {
  const KeyboardAwareListView({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();
    final focusNodes = useMemoized(
      () => List.generate(5, (_) => FocusNode()),
      [],
    );

    // Example list of items
    final items = List.generate(5, (index) => 'Item ${index + 1}');

    useEffect(() {
      void scrollToFocusedTextField() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final focusNode in focusNodes) {
            if (focusNode.hasFocus) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              break;
            }
          }
        });
      }

      WidgetsBinding.instance.addObserver(
        LifecycleEventHandler(
          onDidChangeMetrics: () {
            // Check if the keyboard is visible
            if (View.of(context).viewInsets.bottom > 0.0) {
              scrollToFocusedTextField();
            }
          },
        ),
      );

      // Cleanup function to remove observer
      return () {
        WidgetsBinding.instance.removeObserver(
          LifecycleEventHandler(onDidChangeMetrics: () {}),
        );
      };
    }, [scrollController]);
    //   void metricsChangeHandler() {
    //     if (View.of(context).viewInsets.bottom > 0.0) {
    //       scrollToFocusedTextField();
    //     }
    //   }

    //   // Subscribe to the view metrics changes
    //   PlatformDispatcher.instance.onMetricsChanged = metricsChangeHandler;

    //   // Cleanup function
    //   return () {
    //     PlatformDispatcher.instance.onMetricsChanged = null;
    //   };
    // }, [scrollController, focusNodes]);

    return Scaffold(
      appBar: AppBar(title: Text('Keyboard Aware ListView'.tr())),
      body: ListView.builder(
        controller: scrollController,
        itemCount: items.length + 6,
        itemBuilder: (context, index) {
          final idx = index - 6;
          if (idx < 0) {
            return ListTile(
              title: Text('itemNumber'.tr(namedArgs: {'number': '$idx'})),
            );
          }
          return Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              focusNode: focusNodes[idx],
              decoration: InputDecoration(
                labelText: 'typeSomethingIn'.tr(
                  namedArgs: {'item': items[idx]},
                ),
                border: OutlineInputBorder(),
              ),
              onTap: () {
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Custom Lifecycle Event Handler to detect changes in metrics
class LifecycleEventHandler extends WidgetsBindingObserver {
  final VoidCallback? onDidChangeMetrics;

  LifecycleEventHandler({this.onDidChangeMetrics});

  @override
  void didChangeMetrics() {
    if (onDidChangeMetrics != null) {
      onDidChangeMetrics!();
    }
  }
}
