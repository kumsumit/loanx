import 'package:flutter/material.dart';
import 'family_relation.dart';
import 'mortgage_material.dart';

class Manage extends StatelessWidget {
  const Manage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.secondary,
          tabs: [
            Tab(icon: Text("Mortgage Material")),
            Tab(icon: Text("Family Relation")),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [MortgageMaterialView(), FamilyRelationView()],
          ),
        ),
      ]),
    );
  }
}
