import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'family_relation.dart';
import 'mortgage_material.dart';
import 'weight_units.dart';

class Manage extends StatelessWidget {
  const Manage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TabBar(
                tabs: [
                  Tab(text: LocaleKeys.materials.tr()),
                  Tab(text: LocaleKeys.relations.tr()),
                  Tab(text: LocaleKeys.units.tr()),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                MortgageMaterialView(),
                FamilyRelationView(),
                WeightUnitView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
