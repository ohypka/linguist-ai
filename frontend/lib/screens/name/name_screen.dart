import 'package:flutter/material.dart';
import '../topic/topic_screen.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _nameError;

  Future<void> _proceed() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter your name.');
      return;
    }

    setState(() {
      _loading = true;
      _nameError = null;
    });

    try {
      await ApiService.init(name);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TopicScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                  const Text(
                    "Enter your name to get started",
                    style: TextStyle(fontSize: 16, color: Colors.white54),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _nameController,
                    enabled: !_loading,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _proceed(),
                    onChanged: (v) {
                      if (_nameError != null && v.trim().isNotEmpty) {
                        setState(() => _nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "Your name",
                      hintStyle: const TextStyle(color: Colors.white38),
                      errorText: _nameError,
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
                          color: _nameError == null
                              ? Colors.transparent
                              : Colors.redAccent,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(
                          color: _nameError == null
                              ? Colors.white24
                              : Colors.redAccent,
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
                  ),
                  const SizedBox(height: 28),
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
                                  "Continue",
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
        ),
      ),
    );
  }
}
