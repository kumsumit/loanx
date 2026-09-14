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

class _LanguagePickerLayout {
  const _LanguagePickerLayout._({
    required this.isDense,
    required this.showHero,
    required this.pagePadding,
    required this.bottomPadding,
    required this.sectionGap,
    required this.listGap,
    required this.sheetHeightFactor,
  });

  factory _LanguagePickerLayout.of(Size size, {required bool preferCompact}) {
    final isDense = preferCompact || size.width < 360 || size.height < 640;
    return _LanguagePickerLayout._(
      isDense: isDense,
      // The language controls are more valuable than decoration on a short
      // screen. The hero remains useful on normal and large screens.
      showHero: !preferCompact && size.height >= 560,
      pagePadding: isDense ? 12 : 20,
      bottomPadding: isDense ? 12 : 16,
      sectionGap: isDense ? 12 : 22,
      listGap: isDense ? 10 : 14,
      sheetHeightFactor: isDense ? .92 : .82,
    );
  }

  final bool isDense;
  final bool showHero;
  final double pagePadding;
  final double bottomPadding;
  final double sectionGap;
  final double listGap;
  final double sheetHeightFactor;
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
    final layout = _LanguagePickerLayout.of(
      MediaQuery.sizeOf(context),
      // On a J2-class device, language selection is more useful than the
      // decorative hero, even when Android reports a tall logical screen.
      preferCompact: DeviceCapabilitiesScope.of(context).reduceEffects,
    );
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
                padding: EdgeInsets.fromLTRB(
                  layout.pagePadding,
                  layout.pagePadding,
                  layout.pagePadding,
                  layout.bottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (layout.showHero) ...[
                      _LanguageHero(
                        colors: colors,
                        basicEffects: basicEffects,
                        compact: layout.isDense,
                      ),
                      SizedBox(height: layout.sectionGap),
                    ],
                    Text(
                      LocaleKeys.chooseAppLanguage.tr(),
                      style: layout.isDense
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (!layout.isDense) ...[
                      const SizedBox(height: 6),
                      Text(
                        LocaleKeys.youCanChangeThisLaterFromAppPreferences.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: layout.sectionGap),
                    _LanguageSearch(
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    SizedBox(height: layout.listGap),
                    Expanded(
                      child: _LanguageGrid(
                        selectedLocale: _selectedLocale,
                        query: _query,
                        compact: layout.isDense,
                        onSelected: (locale) =>
                            setState(() => _selectedLocale = locale),
                      ),
                    ),
                    SizedBox(height: layout.listGap),
                    FilledButton.icon(
                      key: const Key('language-continue'),
                      onPressed: _continue,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(LocaleKeys.continueAction.tr()),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(layout.isDense ? 48 : 58),
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
  Widget build(BuildContext context) {
    final layout = _LanguagePickerLayout.of(
      MediaQuery.sizeOf(context),
      preferCompact: DeviceCapabilitiesScope.of(context).reduceEffects,
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * layout.sheetHeightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          layout.pagePadding,
          4,
          layout.pagePadding,
          layout.bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.chooseAppLanguage.tr(),
              style: layout.isDense
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: layout.listGap),
            _LanguageSearch(
              onChanged: (value) => setState(() => query = value),
            ),
            SizedBox(height: layout.listGap),
            Expanded(
              child: _LanguageGrid(
                selectedLocale: selectedLocale,
                query: query,
                compact: layout.isDense,
                onSelected: (locale) => setState(() => selectedLocale = locale),
              ),
            ),
            SizedBox(height: layout.listGap),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(layout.isDense ? 48 : 40),
              ),
              onPressed: () => Navigator.pop(context, selectedLocale),
              child: Text(LocaleKeys.continueAction.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageHero extends StatelessWidget {
  const _LanguageHero({
    required this.colors,
    required this.basicEffects,
    required this.compact,
  });
  final ColorScheme colors;
  final bool basicEffects;
  final bool compact;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      width: compact ? 72 : 96,
      height: compact ? 64 : 82,
      decoration: BoxDecoration(
        color: basicEffects ? colors.primary : null,
        gradient: basicEffects
            ? null
            : LinearGradient(colors: [colors.primary, colors.tertiary]),
        borderRadius: BorderRadius.circular(compact ? 20 : 26),
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
      child: Icon(
        Icons.translate_rounded,
        size: compact ? 34 : 42,
        color: colors.onPrimary,
      ),
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
    required this.compact,
    required this.onSelected,
  });
  final Locale selectedLocale;
  final String query;
  final bool compact;
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
            mainAxisExtent: compact ? 68 : 82,
            crossAxisSpacing: compact ? 8 : 10,
            mainAxisSpacing: compact ? 8 : 10,
          ),
          itemBuilder: (context, index) {
            final language = languages[index];
            return _LanguageCard(
              language: language,
              compact: compact,
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
    required this.compact,
    required this.selected,
    required this.onTap,
  });
  final AppLanguage language;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
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
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 6 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
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
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.nativeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? Theme.of(context).textTheme.titleSmall
                          : Theme.of(context).textTheme.titleMedium,
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
