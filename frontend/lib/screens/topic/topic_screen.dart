import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  String _level = 'B1';
  bool _loading = false;

  static const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  Future<void> _proceed() async {
    setState(() => _loading = true);
    final name = _nameController.text.trim();
    final topic = _topicController.text.trim();
    await ApiService.init(name.isEmpty ? 'Guest' : name);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          topic: topic.isEmpty ? "general" : topic,
          level: _level,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
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
              const SizedBox(height: 32),
              _buildTextField(
                controller: _nameController,
                hint: "Your name",
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _topicController,
                hint: "Topic: travel, food...",
                onSubmitted: (_) => _proceed(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _levels.map((lvl) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _level = lvl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _level == lvl
                              ? const Color(0xFF3B82F6)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            lvl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                widthFactor: 0.45,
                child: GestureDetector(
                  onTap: _loading ? null : _proceed,
                  child: GlassCard(
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
