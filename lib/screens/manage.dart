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
              child: const TabBar(
                tabs: [
                  Tab(text: "Materials"),
                  Tab(text: "Relations"),
                  Tab(text: "Units"),
                ],
              ),
            ),
          ),
          const Expanded(
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
