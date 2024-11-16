import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/mortgage_input.dart';
import 'package:mortgage/screens/mortgage_list_view.dart';

// import 'keyboard_input.dart';

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 10,
          ),
          Consumer(
              builder: (context, ref, child) =>
                  ref.watch(searchBarStatusProvider)
                      ? SearchAppBar()
                      : const SizedBox()),
          MortgageListView()
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add'),
        label: const Text('Add Mortgage'),
        onPressed: () {
          if (context.mounted) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const MortgageInput()));
          }
        },
      ),
    );
  }
}
