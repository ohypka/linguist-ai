import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../../widgets/glass_card.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _controller = TextEditingController();

  void _proceed() {
    final topic = _controller.text.trim();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(topic: topic.isEmpty ? "general" : topic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Linguist AI",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "What topic would you like to practice?",
                style: TextStyle(fontSize: 20, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onSubmitted: (_) => _proceed(),
                decoration: const InputDecoration(
                  hintText: " travel, food...",
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                widthFactor: 0.45,
                child: GestureDetector(
                  onTap: _proceed,
                  child: GlassCard(
                    child: const Center(
                      child: Text(
                        "Start",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
