import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../games/tinder_screen.dart';
import '../chat/chat_screen.dart';
import '../speaking/speaking_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // reusable navigation card (avoids duplicating UI + navigation logic)
  Widget buildCard(
      BuildContext context, String title, IconData icon, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen), // simple navigation
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
          // main background gradient for the home screen
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
            const SizedBox(height: 40),

            // main navigation options
            buildCard(context, "Grammar Cards", Icons.swipe,
                const TinderScreen()),
            const SizedBox(height: 16),
            buildCard(
                context, "Chat with AI", Icons.chat_bubble, const ChatScreen()),
            const SizedBox(height: 16),
            buildCard(
                context, "Speaking Mode", Icons.mic, const SpeakingScreen()),
          ],
        ),
      ),
    );
  }
}