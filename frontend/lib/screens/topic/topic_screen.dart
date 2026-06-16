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
  final _topicController = TextEditingController();

  String _level = 'B1';
  bool _loading = false;

  static const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  Future<void> _proceed() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    final topic = _topicController.text.trim();
    final topicToUse = topic.isEmpty ? 'general' : topic;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          topic: topicToUse,
          level: _level,
        ),
      ),
    );
  }

  @override
  void dispose() {
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Linguist AI",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Hello, ${ApiService.playerName}! Choose your topic and level.",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  _buildTextField(
                    controller: _topicController,
                    hint: "Topic: travel, food...",
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _proceed(),
                  ),

                  const SizedBox(height: 8),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "If you leave topic empty, general English will be used.",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _levels
                        .map(
                          (lvl) => Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: _loading
                                ? null
                                : () => setState(() => _level = lvl),
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _level == lvl
                                    ? const Color(0xFF3B82F6)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _level == lvl
                                      ? Colors.white.withOpacity(0.35)
                                      : Colors.transparent,
                                ),
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
                      ),
                    )
                        .toList(),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: 180,
                    child: GestureDetector(
                      onTap: _loading ? null : _proceed,
                      child: GlassCard(
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            "Start",
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Default topic: general",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onSubmitted,
    ValueChanged<String>? onChanged,
    String? errorText,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      enabled: !_loading,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        errorText: errorText,
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(
            color: errorText == null ? Colors.transparent : Colors.redAccent,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(
            color: errorText == null ? Colors.white24 : Colors.redAccent,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}