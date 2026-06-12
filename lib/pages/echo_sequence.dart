import 'package:flutter/material.dart';

class EchoSequencePage extends StatelessWidget {
  const EchoSequencePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Echo Sequence'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Memory Duo Home',
            onPressed: () => Navigator.of(context).pushNamed('/'),
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: 'About',
            onPressed: () => Navigator.of(context).pushNamed('/about'),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: isDarkMode ? 'Switch to Day Mode' : 'Switch to Night Mode',
            onPressed: onThemeToggle,
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.construction, size: 64),
            SizedBox(height: 16),
            Text(
              'Under Construction',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Echo Sequence is coming soon!'),
          ],
        ),
      ),
    );
  }
}
