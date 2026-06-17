import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/name/name_screen.dart';
import 'screens/topic/topic_screen.dart';
import 'services/api_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: FutureBuilder<bool>(
        future: ApiService.tryAutoInit(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == true) {
            return const TopicScreen();
          }
          return const NameScreen();
        },
      ),
    );
  }
}
