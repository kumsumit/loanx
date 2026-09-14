import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loanx/l10n/app_languages.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/device_capabilities.dart';

Future<void> showAppLanguagePicker(BuildContext context) async {
  final selectedLocale = await showModalBottomSheet<Locale>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _LanguagePickerSheet(initialLocale: context.locale),
  );
  if (selectedLocale != null && context.mounted) {
    await context.setLocale(selectedLocale);
    AppSettings.putPendingPreferredLanguage(selectedLocale.languageCode);
    await AppSettings.flush();
    try {
      await activeAuthClient?.updateLanguage(selectedLocale.languageCode);
      AppSettings.putPendingPreferredLanguage('');
      await AppSettings.flush();
    } catch (_) {
      // The local choice remains active and is retained for a later sync.
    }
  }
}

class StartupLanguageScreen extends StatefulWidget {
  const StartupLanguageScreen({required this.onLanguageSelected, super.key});
  final VoidCallback onLanguageSelected;

  @override
  State<StartupLanguageScreen> createState() => _StartupLanguageScreenState();
}

class _StartupLanguageScreenState extends State<StartupLanguageScreen> {
  late Locale _selectedLocale;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLocale = context.locale;
  }

  Future<void> _continue() async {
    await context.setLocale(_selectedLocale);
    if (mounted) widget.onLanguageSelected();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final basicEffects = DeviceCapabilitiesScope.of(context).useBasicEffects;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: basicEffects ? colors.surface : null,
          gradient: basicEffects
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface,
                    colors.primaryContainer.withValues(alpha: .35),
                  ],
                ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LanguageHero(colors: colors, basicEffects: basicEffects),
                    const SizedBox(height: 22),
                    Text(
                      LocaleKeys.chooseAppLanguage.tr(),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LocaleKeys.youCanChangeThisLaterFromAppPreferences.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LanguageSearch(
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _LanguageGrid(
                        selectedLocale: _selectedLocale,
                        query: _query,
                        onSelected: (locale) =>
                            setState(() => _selectedLocale = locale),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('language-continue'),
                      onPressed: _continue,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(LocaleKeys.continueAction.tr()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({required this.initialLocale});
  final Locale initialLocale;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late Locale selectedLocale = widget.initialLocale;
  String query = '';

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .82,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.chooseAppLanguage.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          _LanguageSearch(onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 14),
          Expanded(
            child: _LanguageGrid(
              selectedLocale: selectedLocale,
              query: query,
              onSelected: (locale) => setState(() => selectedLocale = locale),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.pop(context, selectedLocale),
            child: Text(LocaleKeys.continueAction.tr()),
          ),
        ],
      ),
    ),
  );
}

class _LanguageHero extends StatelessWidget {
  const _LanguageHero({required this.colors, required this.basicEffects});
  final ColorScheme colors;
  final bool basicEffects;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      width: 96,
      height: 82,
      decoration: BoxDecoration(
        color: basicEffects ? colors.primary : null,
        gradient: basicEffects
            ? null
            : LinearGradient(colors: [colors.primary, colors.tertiary]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: basicEffects
            ? null
            : [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .24),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Icon(Icons.translate_rounded, size: 42, color: colors.onPrimary),
    ),
  );
}

class _LanguageSearch extends StatelessWidget {
  const _LanguageSearch({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('language-search'),
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: LocaleKeys.searchLanguage.tr(),
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: const Icon(Icons.tune_rounded),
    ),
  );
}

class _LanguageGrid extends StatelessWidget {
  const _LanguageGrid({
    required this.selectedLocale,
    required this.query,
    required this.onSelected,
  });
  final Locale selectedLocale;
  final String query;
  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final languages = appLanguages.where((language) {
      return language.nativeName.toLowerCase().contains(normalizedQuery) ||
          language.englishName.toLowerCase().contains(normalizedQuery);
    }).toList();
    if (languages.isEmpty) {
      return Center(child: Text(LocaleKeys.noDataFound.tr()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        return GridView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: languages.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 82,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final language = languages[index];
            return _LanguageCard(
              language: language,
              selected:
                  selectedLocale.languageCode == language.locale.languageCode,
              onTap: () => onSelected(language.locale),
            );
          },
        );
      },
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.onTap,
  });
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('language-${language.locale.languageCode}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary
                      : colors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  language.locale.languageCode.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.nativeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (language.nativeName != language.englishName)
                      Text(
                        language.englishName,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
