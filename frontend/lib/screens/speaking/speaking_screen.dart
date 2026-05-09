import 'package:flutter/material.dart';
import '../../services/speech_service.dart';

class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({super.key});

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  final SpeechService speechService = SpeechService();

  bool recording = false;
  String transcript = "";
  String result = "";

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  Future<void> initSpeech() async {
    await speechService.init();
  }

  Future<void> toggle() async {
    try {
      if (!recording) {
        // start speech recognition
        await speechService.startListening((text) {
          setState(() {
            transcript = text;
          });
        });

        setState(() {
          recording = true;
          result = "";
        });
      } else {
        // stop speech recognition
        await speechService.stopListening();

        setState(() {
          recording = false;
          result = transcript.isNotEmpty
              ? "Speech recognized successfully"
              : "No speech detected";
        });
      }
    } catch (e) {
      setState(() {
        recording = false;
        result = "Speech recognition error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Speaking Mode"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Describe your last vacation",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              GestureDetector(
                onTap: toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: recording
                          ? [
                        Colors.redAccent,
                        Colors.deepOrange,
                      ]
                          : [
                        const Color(0xFF3B82F6),
                        const Color(0xFF8B5CF6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: recording
                            ? Colors.redAccent.withOpacity(0.5)
                            : Colors.blueAccent.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    recording ? Icons.stop : Icons.mic,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Text(
                recording
                    ? "Listening..."
                    : "Tap the microphone to speak",
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  transcript.isEmpty
                      ? "Your speech transcript will appear here..."
                      : transcript,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                result,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.greenAccent,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}