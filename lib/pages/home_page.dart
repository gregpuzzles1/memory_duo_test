import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({
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
        automaticallyImplyLeading: false,
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        centerTitle: true,
        title: const Text('Welcome to Memory Duo'),
        actions: <Widget>[
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Memory Duo',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  'Flip matching pairs, complete levels, and track your results.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/game'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Game'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/echo-sequence'),
                  icon: const Icon(Icons.queue_music_outlined),
                  label: const Text('Echo Sequence'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
