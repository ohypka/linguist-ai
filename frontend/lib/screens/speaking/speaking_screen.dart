import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../services/api_service.dart';

class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({super.key});

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  final audio = AudioService();
  bool recording = false;
  String result = "";
  String? path;

  void toggle() async {
    try {
      if (!recording) {
        // start recording
        path = await audio.start();
      } else {
        final filePath = await audio.stop();

        // emulator fallback (no audio file created)
        if (filePath == null || filePath.isEmpty) {
          setState(() {
            result = "⚠️ Microphone not available on emulator";
          });
          return;
        }

        // send recorded file to backend
        final res = await ApiService.analyzeAudio(filePath);

        setState(() {
          result = res["feedback"] ?? "No feedback"; // safe fallback
        });
      }

      setState(() => recording = !recording);
    } catch (e) {
      // handles recording/API errors
      setState(() {
        result = "⚠️ Recording error (emulator limitation)";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Speaking Mode")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Describe your last vacation",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: toggle, // start/stop recording
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: const Icon(Icons.mic, size: 50),
              ),
            ),
            const SizedBox(height: 20),
            Text(result), // displays API feedback or error
          ],
        ),
      ),
    );
  }
}