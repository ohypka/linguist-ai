import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/speech_service.dart';

import '../../widgets/game_card.dart';
import '../../widgets/mic_button.dart';

class QuickReactionsScreen extends StatefulWidget {
  const QuickReactionsScreen({super.key});

  @override
  State<QuickReactionsScreen> createState() =>
      _QuickReactionsScreenState();
}

class _QuickReactionsScreenState extends State<QuickReactionsScreen> {
  final SpeechService speechService = SpeechService();
  bool speechEnabled = false;
  bool recording = false;
  String recognizedText = "";

  final List<String> mockPool = [
    "Excuse me, you just stepped on my invisible dog!",
    "Why are you wearing pajamas to a business meeting?",
    "I think your socks don't match, and it's bothering everyone.",
    "Did you know that penguins have knees?",
    "I just heard you got rejected by three places today.",
  ];

  int index = 0;
  int score = 0;

  String? gameId;
  String prompt = "";

  bool showOverlay = false;
  bool showWrongOverlay = false;

  int timeLeft = 5;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    initSpeech();
    loadCard();
  }

  Future<void> initSpeech() async {
    speechEnabled = await speechService.init();
    if (!mounted) return;
    setState(() {});
  }

  Future<Map<String, dynamic>> mockStartGame() async {
    await Future.delayed(const Duration(milliseconds: 250));

    return {
      "game_id": "mock_quick_$index",
      "prompt": mockPool[index],
    };
  }

  Future<Map<String, dynamic>> mockEvaluate(String userText) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final success =
        userText.trim().length > 5 &&
            DateTime.now().millisecond % 2 == 0;

    return {
      "round_success": success,
      "feedback": success
          ? "Nice reaction!"
          : "Too slow or weak response.",
    };
  }

  Future<void> loadCard() async {
    final res = await mockStartGame();

    setState(() {
      gameId = res["game_id"];
      prompt = res["prompt"];
      timeLeft = 5;
      recognizedText = "";
      recording = false;
    });

    startTimer();
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (timeLeft == 0) {
        t.cancel();
        if (!mounted) return;

        setState(() => showWrongOverlay = true);

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        setState(() => showWrongOverlay = false);

        nextCard();
      } else {
        if (mounted) {
          setState(() => timeLeft--);
        }
      }
    });
  }

  void toggleRecording() async {
    if (!speechEnabled) return;

    if (!recording) {
      await speechService.startListening((text)
        {
          if (!mounted) return;
          setState(() => recognizedText = text);
        },
      );
    } else {
      await speechService.stopListening();
    }

    if (mounted) {
      setState(() => recording = !recording);
    }
  }

  Future<void> submit({bool autoFail = false}) async {
    timer?.cancel();

    final res = await mockEvaluate(
      autoFail ? "" : recognizedText,
    );

    if (!mounted) return;

    final success = res["round_success"];
    final feedback = res["feedback"];

    if (success) {
      score++;

      if (mounted) setState(() => showOverlay = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => showOverlay = false);

    } else {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Result"),
          content: Text(feedback),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Next"),
            )
          ],
        ),
      );
    }

    nextCard();
  }

  void nextCard() {
    if (index < mockPool.length - 1) {
      setState(() => index++);
      loadCard();
    } else {
      endGame();
    }
  }


  void endGame() {
    timer?.cancel();

    final accuracy =
    (score / mockPool.length * 100).toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Your result"),
        content: Text("Score: $score\nAccuracy: $accuracy%"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              setState(() {
                index = 0;
                score = 0;
              });

              loadCard();
            },
            child: const Text("Restart"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    speechService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Card ${index + 1}/${mockPool.length}"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Text(
            "Time: $timeLeft",
            style: const TextStyle(fontSize: 20),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Center(
              child: GameCard(
                showOverlay: showOverlay || showWrongOverlay,
                overlayColor:
                showWrongOverlay ? Colors.red : Colors.green,
                overlayIcon:
                showWrongOverlay ? Icons.close : Icons.check,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(recording ? "Listening..." : "Tap mic"),

          const SizedBox(height: 10),

          MicButton(
            recording: recording,
            onTap: toggleRecording,
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: submit,
            child: const Text("Reply"),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}