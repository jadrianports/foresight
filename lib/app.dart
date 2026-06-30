import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Placeholder root for the scaffold (Story 1.1). Proves the project builds and the
/// two bundled fonts render fully offline. Real theming (Story 1.5) and screens
/// (Epic 3+) replace this — keep it deliberately minimal.
class ForesightApp extends StatelessWidget {
  const ForesightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foresight',
      debugShowCheckedModeBanner: false,
      home: const _ScaffoldCheckScreen(),
    );
  }
}

class _ScaffoldCheckScreen extends StatelessWidget {
  const _ScaffoldCheckScreen();

  @override
  Widget build(BuildContext context) {
    // Display/accent role → Press Start 2P. Body/data role → Nunito.
    // Both come from the bundled assets (allowRuntimeFetching=false in main()).
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FORESIGHT',
              style: GoogleFonts.pressStart2p(fontSize: 22, height: 1.1),
            ),
            const SizedBox(height: 20),
            Text(
              'Scaffold online — fonts bundled, offline.',
              style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
