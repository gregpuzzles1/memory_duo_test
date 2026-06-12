import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'pages/about.dart';
import 'pages/echo_sequence.dart';
import 'pages/home_page.dart';
import 'pages/memory_duo.dart';

void main() {
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Duo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (BuildContext context) => HomePage(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeToggle: _toggleTheme,
            ),
        '/game': (BuildContext context) => MemoryGamePage(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeToggle: _toggleTheme,
            ),
        '/echo-sequence': (BuildContext context) => EchoSequencePage(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeToggle: _toggleTheme,
            ),
        '/about': (BuildContext context) => AboutPage(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeToggle: _toggleTheme,
            ),
      },
    );
  }
}
