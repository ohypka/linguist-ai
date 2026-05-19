import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool recording;
  final VoidCallback onTap;

  const MicButton({
    super.key,
    required this.recording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: recording ? 100 : 90,
        height: recording ? 100 : 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            if (recording)
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.6),
                blurRadius: 30,
                spreadRadius: 5,
              )
          ],
        ),
        child: Icon(
          recording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}