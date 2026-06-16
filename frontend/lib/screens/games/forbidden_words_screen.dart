import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/speech_service.dart';
import '../../widgets/game_card.dart';
import '../../widgets/mic_button.dart';
import '../leaderboard/leaderboard_screen.dart';

class ForbiddenWordsScreen extends StatefulWidget {
  final String topic;
  final String level;

  const ForbiddenWordsScreen({
    super.key,
    required this.topic,
    required this.level,
  });

  @override
  State<ForbiddenWordsScreen> createState() => _ForbiddenWordsScreenState();
}

class _ForbiddenWordsScreenState extends State<ForbiddenWordsScreen> {
  static const int totalRounds = 3;
  static const int roundDuration = 60;

  final SpeechService speechService = SpeechService();

  bool speechEnabled = false;
  bool recording = false;
  bool isLoading = true;
  bool isSubmitting = false;

  String recognizedText = "";
  String? errorMessage;

  int index = 0;
  int correctRounds = 0;
  int totalScore = 0;

  String? gameId;
  String target = "";
  List<String> forbidden = [];

  bool showCorrectOverlay = false;
  bool showWrongOverlay = false;

  int timeLeft = roundDuration;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    initSpeech();
    loadCard();
  }

  Future<void> initSpeech() async {
    try {
      speechEnabled = await speechService.init();
    } catch (_) {
      speechEnabled = false;
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> loadCard() async {
    timer?.cancel();

    if (recording) {
      await speechService.stopListening();
      if (mounted) {
        setState(() => recording = false);
      }
    }

    setState(() {
      isLoading = true;
      isSubmitting = false;
      errorMessage = null;
      recognizedText = "";
      showCorrectOverlay = false;
      showWrongOverlay = false;
    });

    try {
      await ApiService.ensureRegistered();

      final res = await ApiService.startForbiddenWords(
        widget.topic,
        level: widget.level,
      );

      if (!mounted) return;

      setState(() {
        gameId = res["game_id"]?.toString();
        target = res["target_word"]?.toString() ?? "";
        forbidden = List<String>.from(res["forbidden_words"] ?? []);
        timeLeft = roundDuration;
        recording = false;
        isLoading = false;
      });

      startTimer();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = "Could not load Forbidden Words round.\n$e";
      });
    }
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted || isSubmitting) return;

      if (timeLeft <= 1) {
        t.cancel();
        await _submitAnswer(isTimeout: true);
      } else {
        setState(() => timeLeft--);
      }
    });
  }

  Future<void> toggleRecording() async {
    if (isSubmitting) return;

    if (!speechEnabled) {
      _showSnackBar("Speech recognition is not available.");
      return;
    }

    if (!recording) {
      await speechService.startListening((text) {
        if (!mounted) return;

        setState(() {
          recognizedText = text;
        });
      });
    } else {
      await speechService.stopListening();
    }

    if (!mounted) return;

    setState(() {
      recording = !recording;
    });
  }

  Future<void> submit() async {
    await _submitAnswer(isTimeout: false);
  }

  Future<void> _submitAnswer({
    required bool isTimeout,
  }) async {
    if (isSubmitting) return;

    if (gameId == null || gameId!.isEmpty) {
      _showSnackBar("Cannot submit answer because game ID is missing.");
      return;
    }

    timer?.cancel();

    if (recording) {
      await speechService.stopListening();
      if (mounted) {
        setState(() => recording = false);
      }
    }

    final userAnswer = recognizedText.trim();
    final textToSend = isTimeout || userAnswer.isEmpty ? "..." : userAnswer;

    setState(() {
      isSubmitting = true;
    });

    try {
      final res = await ApiService.evaluateForbiddenWords(
        gameId: gameId!,
        userText: textToSend,
      );

      if (!mounted) return;

      final bool apiSuccess = res["round_success"] as bool? ?? false;
      final String apiFeedback =
          res["feedback"]?.toString() ?? "No feedback returned.";

      final int roundScore = (res["score"] as num?)?.toInt() ?? 0;

      final bool success = !isTimeout && userAnswer.isNotEmpty && apiSuccess;

      final String feedback = isTimeout
          ? "Time is up. This round counts as 0 points."
          : userAnswer.isEmpty
          ? "You didn't say anything. This round counts as 0 points."
          : apiFeedback;

      totalScore += roundScore;

      if (success) {
        correctRounds++;

        setState(() {
          showCorrectOverlay = true;
          showWrongOverlay = false;
        });
      } else {
        setState(() {
          showCorrectOverlay = false;
          showWrongOverlay = true;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      await _showRoundFeedbackDialog(
        success: success,
        feedback: feedback,
        roundScore: roundScore,
        isTimeout: isTimeout,
      );

      if (!mounted) return;

      setState(() {
        showCorrectOverlay = false;
        showWrongOverlay = false;
        isSubmitting = false;
      });

      nextCard();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      _showSnackBar("Could not evaluate your answer. Try again.");

      if (!isTimeout) {
        startTimer();
      }
    }
  }

  Future<void> _showRoundFeedbackDialog({
    required bool success,
    required String feedback,
    required int roundScore,
    required bool isTimeout,
  }) async {
    String title;

    if (isTimeout) {
      title = "Time is up";
    } else if (success) {
      title = "Correct";
    } else {
      title = "AI didn't guess it";
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.cancel,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feedback),
              const SizedBox(height: 12),
              Text(
                "Round score: $roundScore pts",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  void nextCard() {
    if (index < totalRounds - 1) {
      setState(() {
        index++;
      });

      loadCard();
    } else {
      endGame();
    }
  }

  Future<void> endGame() async {
    timer?.cancel();

    try {
      await ApiService.endForbiddenWords(totalScore);
    } catch (_) {
      _showSnackBar("Final score could not be saved to leaderboard.");
    }

    if (!mounted) return;

    final accuracy = (correctRounds / totalRounds * 100).toStringAsFixed(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Your result"),
        content: Text(
          "Correct rounds: $correctRounds/$totalRounds\n"
              "Accuracy: $accuracy%\n"
              "Total score: $totalScore pts",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                index = 0;
                correctRounds = 0;
                totalScore = 0;
              });
              loadCard();
            },
            child: const Text("Restart"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen(),
                ),
              );
            },
            child: const Text("Leaderboard"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Back to menu"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Forbidden Words"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage ?? "Something went wrong.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: loadCard,
                icon: const Icon(Icons.refresh),
                label: const Text("Try again"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptBox() {
    final text = recognizedText.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your speech:",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty
                ? "Nothing recognized yet. Tap the microphone and describe the word."
                : text,
            style: TextStyle(
              color: text.isEmpty ? Colors.white38 : Colors.white,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForbiddenWords() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: forbidden
          .map(
            (word) => Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.35),
            ),
          ),
          child: Text(
            word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      )
          .toList(),
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
      return _buildLoadingView();
    }

    if (errorMessage != null) {
      return _buildErrorView();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Word ${index + 1}/$totalRounds"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "$totalScore pts",
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),

              Text(
                "Time: $timeLeft",
                style: TextStyle(
                  fontSize: 20,
                  color: timeLeft <= 5 ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Center(
                  child: GameCard(
                    showOverlay: showCorrectOverlay || showWrongOverlay,
                    overlayColor:
                    showWrongOverlay ? Colors.redAccent : Colors.green,
                    overlayIcon:
                    showWrongOverlay ? Icons.close : Icons.check,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Describe this word:",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            target.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            "Forbidden words:",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildForbiddenWords(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _buildTranscriptBox(),

              const SizedBox(height: 14),

              Text(
                recording
                    ? "Listening..."
                    : speechEnabled
                    ? "Tap mic and describe the word"
                    : "Speech recognition unavailable",
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 10),

              MicButton(
                recording: recording,
                onTap: isSubmitting
                    ? () {}
                    : () {
                  toggleRecording();
                },
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submit,
                    child: isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text("Submit"),
                  ),
                ),
              ),

              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}