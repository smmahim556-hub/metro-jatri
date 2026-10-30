import 'package:flutter/material.dart';

import 'screens/lines_screen.dart';
import 'screens/ride_screen.dart';

void main() => runApp(const MetroJatriApp());

class MetroJatriApp extends StatelessWidget {
  const MetroJatriApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0A7D4F);
    return MaterialApp(
      title: 'মেট্রো যাত্রী',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          useMaterial3: true),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The map runs edge to edge; each screen handles its own safe area.
      body: IndexedStack(
        index: _tab,
        children: const [RideScreen(), SafeArea(child: LinesScreen())],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.train), label: 'যাত্রা'),
          NavigationDestination(icon: Icon(Icons.map), label: 'লাইনসমূহ'),
        ],
      ),
    );
  }
}
