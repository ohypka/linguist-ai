import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/speech_service.dart';
import '../../widgets/game_card.dart';
import '../../widgets/mic_button.dart';

class ForbiddenWordsScreen extends StatefulWidget {
  final String topic;

  const ForbiddenWordsScreen({super.key, required this.topic});

  @override
  State<ForbiddenWordsScreen> createState() => _ForbiddenWordsScreenState();
}

class _ForbiddenWordsScreenState extends State<ForbiddenWordsScreen> {
  static const totalRounds = 3;

  final SpeechService speechService = SpeechService();
  bool speechEnabled = false;
  bool recording = false;
  String recognizedText = "";

  bool isLoading = true;

  int index = 0;
  int score = 0;

  String? gameId;
  String target = "";
  List<String> forbidden = [];

  bool showOverlay = false;
  bool showWrongOverlay = false;

  int timeLeft = 30;
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

  Future<void> loadCard() async {
    setState(() => isLoading = true);

    try {
      await ApiService.ensureRegistered();
      final res = await ApiService.startForbiddenWords("${widget.topic} ${index + 1}");

      setState(() {
        gameId = res["game_id"];
        target = res["target_word"];
        forbidden = List<String>.from(res["forbidden_words"]);
        timeLeft = 30;
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

    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (timeLeft == 0) {
        t.cancel();
        if (!mounted) return;

        setState(() => showWrongOverlay = true);
        await Future.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;
        setState(() => showWrongOverlay = false);

        nextCard();
      } else {
        if (mounted) setState(() => timeLeft--);
      }
    });
  }

  void toggleRecording() async {
    if (!speechEnabled) return;

    if (!recording) {
      debugPrint("start listening");

      await speechService.startListening((text)
        {
          if (mounted) {
            setState(() => recognizedText = text);
          }

          debugPrint("live: $recognizedText");
        },
      );
    } else {
      debugPrint("stop listening");
      await speechService.stopListening();
    }

    if (mounted) setState(() => recording = !recording);
  }

  Future<void> submit() async {
    timer?.cancel();

    try {
      final res = await ApiService.evaluateForbiddenWords(
        gameId: gameId!,
        userText: recognizedText.isEmpty ? "..." : recognizedText,
      );

      if (!mounted) return;

      final success = res["round_success"] as bool;
      final feedback = res["feedback"] as String;

      if (success) {
        score++;
        setState(() => showOverlay = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => showOverlay = false);
      } else {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("AI didn't guess it"),
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
    } catch (e) {
      if (!mounted) return;
    }

    nextCard();
  }

  void nextCard() {
    if (index < totalRounds - 1) {
      setState(() => index++);
      loadCard();
    } else {
      endGame();
    }
  }

  void endGame() {
    timer?.cancel();

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
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Word ${index + 1}/$totalRounds"),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      target.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: forbidden
                          .map(
                            (w) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(w, style: const TextStyle(fontSize: 18)),
                            ),
                          )
                          .toList(),
                    ),
                  ],
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
            child: const Text("Submit"),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
