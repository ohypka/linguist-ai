import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/home/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // global app theme
      home: const HomeScreen(), // entry screen
    );
  }
}