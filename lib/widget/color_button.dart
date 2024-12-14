// import 'package:flutter/material.dart';
// import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:loanx/provider/provider.dart';
// import 'package:loanx/widget/styled_text.dart';

// class ColorButton extends StatelessWidget {
//   const ColorButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//         icon: Icon(Icons.color_lens),
//         onPressed: () {
//           _showDialog(context);
//         });
//   }

//   void _showDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: SingleChildScrollView(
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     const StyledHeading('Pick a color!'),
//                     Consumer(builder: (context, ref, child) {
//                       return IconButton(
//                         icon: Icon(Icons.light_mode),
//                         onPressed:
//                             ref.read(themeModeManagerProvider.notifier).set,
//                       );
//                     }),
//                   ],
//                 ),
//                 Consumer(builder: (context, ref, child) {
//                   final color = ref.watch(pickerColorProvider);
//                   return ColorPicker(
//                       pickerColor: Color(int.parse(color, radix: 16)),
//                       onColorChanged: (color) {
//                         ref.read(pickerColorProvider.notifier).set(color);
//                       });
//                 }),
//                 Consumer(builder: (context, ref, child) {
//                   return OutlinedButton(
//                     child: const Text('Got it'),
//                     onPressed: () async {
//                       await ref.read(appColorProvider.notifier).set();
//                       // Navigator.of(context).pop();
//                       if (context.mounted) {
//                         _showBottomSheet(context);
//                       }
//                     },
//                   );
//                 })
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void _showBottomSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext context) {
//         return Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: GridView(
//               shrinkWrap: true,
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2, // Number of columns in the grid
//                 crossAxisSpacing: 10, mainAxisSpacing: 10,
//                 childAspectRatio: 2.5,
//               ),
//               children: [
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.primary,
//                     text: "Primary"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onPrimary,
//                     text: "onPrimary"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.primaryContainer,
//                     text: "primaryContainer"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onPrimaryContainer,
//                     text: "onPrimaryContainer"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.primaryFixed,
//                     text: "PrimaryFixed"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onPrimaryFixed,
//                     text: "onPrimaryFixed"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.primaryFixedDim,
//                     text: "primaryFixedDim"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onPrimaryFixedVariant,
//                     text: "onPrimaryFixedVariant"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.secondary,
//                     text: "secondary"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onSecondary,
//                     text: "onSecondary"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.secondaryContainer,
//                     text: "secondaryContainer"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onSecondaryContainer,
//                     text: "onSecondaryContainer"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.secondaryFixed,
//                     text: "secondaryFixed"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onSecondaryFixed,
//                     text: "onSecondaryFixed"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.secondaryFixedDim,
//                     text: "secondaryFixedDim"),
//                 ColorCircle(
//                     color:
//                         Theme.of(context).colorScheme.onSecondaryFixedVariant,
//                     text: "onSecondaryFixedVariant"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.tertiary,
//                     text: "tertiary"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onTertiary,
//                     text: "onTertiary"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.tertiaryContainer,
//                     text: "tertiaryContainer"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onTertiaryContainer,
//                     text: "onTertiaryContainer"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.tertiaryFixed,
//                     text: "tertiaryFixed"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onTertiaryFixed,
//                     text: "onTertiaryFixed"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.tertiaryFixedDim,
//                     text: "tertiaryFixedDim"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onTertiaryFixedVariant,
//                     text: "onTertiaryFixedVariant"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onSurface,
//                     text: "onSurface"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onSurfaceVariant,
//                     text: "onSurfaceVariant"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.inversePrimary,
//                     text: "inversePrimary"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.inverseSurface,
//                     text: "inverseSurface"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.outline,
//                     text: "outline"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.outlineVariant,
//                     text: "outlineVariant"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onError,
//                     text: "onError"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.onErrorContainer,
//                     text: "onErrorContainer"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.error, text: "error"),
//                 ColorCircle(
//                     color: Theme.of(context).colorScheme.errorContainer,
//                     text: "errorContainer"),
//                 SizedBox(height: 10),
//                 Center(
//                   child: OutlinedButton(
//                     onPressed: () {
//                       Navigator.pop(context); // Dismiss the bottom sheet
//                     },
//                     child: Text('Close'),
//                   ),
//                 ),
//               ]),
//         );
//       },
//     );
//   }
// }

// class ColorCircle extends StatelessWidget {
//   const ColorCircle({super.key, required this.color, required this.text});
//   final Color color;
//   final String text;
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       children: [
//         SizedBox(
//           height: 40,
//           child: DecoratedBox(
//               decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(20),
//           )),
//         ),
//         Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
//       ],
//     );
//   }
// }
