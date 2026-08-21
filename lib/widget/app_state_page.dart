import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AppStatePage extends StatelessWidget {
  const AppStatePage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = isError ? colors.error : colors.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isError
                          ? colors.errorContainer
                          : colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 48, color: accent),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title.trExists() ? title.tr() : title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message.trExists() ? message.tr() : message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...actions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(width: double.infinity, child: action),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
