import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/widget/search_bar.dart';

import 'family_relation.dart';
import 'item.dart';
import 'mortgage_material.dart';

class Manage extends StatelessWidget {
  const Manage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Consumer(
            builder: (context, ref, child) => ref.watch(searchBarStatusProvider)
                ? SearchAppBar()
                : const SizedBox()),
        TabBar(
          tabs: [
            Tab(icon: Text("Item")),
            Tab(icon: Text("Mortgage Material")),
            Tab(icon: Text("Family Relation")),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              ItemView(),
              MortgageMaterialView(),
              FamilyRelationView()
            ],
          ),
        ),
      ]),
    );
  }
}
