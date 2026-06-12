import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/speech_service.dart';
import '../../widgets/game_card.dart';
import '../../widgets/mic_button.dart';

class QuickReactionsScreen extends StatefulWidget {
  final String topic;
  final String level;

  const QuickReactionsScreen({super.key, this.topic = 'general', this.level = 'B1'});

  @override
  State<QuickReactionsScreen> createState() => _QuickReactionsScreenState();
}

class _QuickReactionsScreenState extends State<QuickReactionsScreen> {
  static const totalRounds = 5;

  final SpeechService speechService = SpeechService();
  bool speechEnabled = false;
  bool recording = false;
  String recognizedText = "";

  bool isLoading = true;

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
    loadFirstCard();
  }

  Future<void> initSpeech() async {
    speechEnabled = await speechService.init();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> loadFirstCard() async {
    setState(() => isLoading = true);

    try {
      await ApiService.ensureRegistered();
      final res = await ApiService.startQuickReactions(topic: widget.topic, level: widget.level);

      setState(() {
        gameId = res["game_id"];
        prompt = res["prompt"];
        timeLeft = 5;
        recognizedText = "";
        recording = false;
        isLoading = false;
      });

      startTimer();
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void startTimer() {
    timer?.cancel();
    timeLeft = 5;

    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (timeLeft == 0) {
        t.cancel();
        if (!mounted) return;

        setState(() => showWrongOverlay = true);
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;
        setState(() => showWrongOverlay = false);

        await submit(autoFail: true);
      } else {
        if (mounted) setState(() => timeLeft--);
      }
    });
  }

  void toggleRecording() async {
    if (!speechEnabled) return;

    if (!recording) {
      await speechService.startListening((text) {
        if (!mounted) return;
        setState(() => recognizedText = text);
      });
    } else {
      await speechService.stopListening();
    }

    if (mounted) setState(() => recording = !recording);
  }

  Future<void> submit({bool autoFail = false}) async {
    timer?.cancel();

    if (recording) {
      await speechService.stopListening();
      if (mounted) setState(() => recording = false);
    }

    try {
      final res = await ApiService.evaluateQuickReactions(
        gameId: gameId!,
        userText: (autoFail || recognizedText.isEmpty) ? "..." : recognizedText,
      );

      if (!mounted) return;

      final success = res["round_success"] as bool;
      final feedback = res["feedback"] as String;
      final nextPrompt = res["next_prompt"] as String;

      if (success) {
        score++;
        setState(() => showOverlay = true);
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

      if (mounted) {
        setState(() {
          prompt = nextPrompt;
          timeLeft = 5;
          recognizedText = "";
          recording = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
    }

    nextCard();
  }

  void nextCard() {
    if (index < totalRounds - 1) {
      setState(() => index++);
      startTimer();
    } else {
      endGame();
    }
  }

  void endGame() {
    timer?.cancel();

    ApiService.endQuickReactions(gameId!).then((res) {
      if (!mounted) return;

      final finalFeedback = res["final_feedback"] as String? ?? "";
      final accuracy = (score / totalRounds * 100).toStringAsFixed(0);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Your result"),
          content: Text("Score: $score\nAccuracy: $accuracy%\n\n$finalFeedback"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  index = 0;
                  score = 0;
                });
                loadFirstCard();
              },
              child: const Text("Restart"),
            )
          ],
        ),
      );
    }).catchError((_) {
      if (!mounted) return;

      final accuracy = (score / totalRounds * 100).toStringAsFixed(0);

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
                loadFirstCard();
              },
              child: const Text("Restart"),
            )
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    speechService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Round ${index + 1}/$totalRounds"),
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
                overlayColor: showWrongOverlay ? Colors.red : Colors.green,
                overlayIcon: showWrongOverlay ? Icons.close : Icons.check,
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

          MicButton(recording: recording, onTap: toggleRecording),

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
