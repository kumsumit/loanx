import 'package:flutter/material.dart';
import 'family_relation.dart';
import 'mortgage.dart';
import 'mortgage_material.dart';

class Manage extends StatelessWidget {
  const Manage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        TabBar(
          tabs: [
            Tab(icon: Text("Mortgage")),
            Tab(icon: Text("Mortgage Material")),
            Tab(icon: Text("Family Relation")),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              MortgageView(),
              MortgageMaterialView(),
              FamilyRelationView()
            ],
          ),
        ),
      ]),
    );
  }
}
