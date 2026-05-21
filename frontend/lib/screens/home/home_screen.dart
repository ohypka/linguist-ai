import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../games/tinder_screen.dart';
import '../speaking/speaking_screen.dart';
import '../games/forbidden_words_screen.dart';
import '../games/quick_reactions_screen.dart';

class HomeScreen extends StatelessWidget {
  final String topic;

  const HomeScreen({super.key, required this.topic});

  Widget buildCard(
      BuildContext context, String title, IconData icon, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: GlassCard(
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Linguist AI",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Topic: $topic",
              style: const TextStyle(fontSize: 20, color: Colors.white54),
            ),
            const SizedBox(height: 40),

            buildCard(context, "Grammar Cards", Icons.swipe,
                const TinderScreen()),
            const SizedBox(height: 16),
            buildCard(context, "Forbidden Words", Icons.swipe,
                ForbiddenWordsScreen(topic: topic)),
            const SizedBox(height: 16),
            buildCard(context, "Quick Reactions", Icons.swipe,
                const QuickReactionsScreen()),
            const SizedBox(height: 16),
            buildCard(
                context, "Speaking Mode", Icons.mic, const SpeakingScreen()),
          ],
        ),
      ),
    );
  }
}
