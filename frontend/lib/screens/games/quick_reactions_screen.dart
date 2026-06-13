import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/speech_service.dart';
import '../../widgets/mic_button.dart';
import '../leaderboard/leaderboard_screen.dart';

class QuickReactionsScreen extends StatefulWidget {
  final String topic;
  final String level;

  const QuickReactionsScreen({
    super.key,
    required this.topic,
    required this.level,
  });

  @override
  State<QuickReactionsScreen> createState() => _QuickReactionsScreenState();
}

class _QuickReactionsScreenState extends State<QuickReactionsScreen> {
  static const int totalRounds = 3;
  static const int roundDuration = 60;

  final SpeechService speechService = SpeechService();

  bool speechEnabled = false;
  bool recording = false;
  bool isLoading = true;
  bool isSubmitting = false;

  String? errorMessage;

  String? gameId;
  String prompt = "";
  String recognizedText = "";

  int currentRound = 1;
  int successfulRounds = 0;
  int totalScore = 0;
  int timeLeft = roundDuration;

  Timer? timer;

  final List<Map<String, dynamic>> roundResults = [];

  @override
  void initState() {
    super.initState();
    initSpeech();
    startGame();
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

  Future<void> startGame() async {
    timer?.cancel();

    if (recording) {
      await speechService.stopListening();
    }

    setState(() {
      isLoading = true;
      isSubmitting = false;
      errorMessage = null;
      recording = false;
      recognizedText = "";
      prompt = "";
      gameId = null;
      currentRound = 1;
      successfulRounds = 0;
      totalScore = 0;
      timeLeft = roundDuration;
      roundResults.clear();
    });

    try {
      await ApiService.ensureRegistered();

      final res = await ApiService.startQuickReactions(
        topic: widget.topic,
        level: widget.level,
      );

      if (!mounted) return;

      setState(() {
        gameId = res["game_id"]?.toString();
        prompt = _extractPrompt(res);
        isLoading = false;
      });

      startTimer();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = "Could not start Quick Reactions.\n$e";
      });
    }
  }

  String _extractPrompt(Map<String, dynamic> response) {
    final possibleKeys = [
      "prompt",
      "text",
      "challenge",
      "reaction_prompt",
    ];

    for (final key in possibleKeys) {
      final value = response[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return "Say anything in English as quickly as you can.";
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
    if (isSubmitting || isLoading) return;

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
      final res = await ApiService.evaluateQuickReactions(
        gameId: gameId!,
        userText: textToSend,
      );

      if (!mounted) return;

      final bool apiSuccess = res["round_success"] as bool? ?? false;
      final bool success = !isTimeout && userAnswer.isNotEmpty && apiSuccess;

      final String feedback = isTimeout
          ? "Time is up. This round counts as 0 points."
          : userAnswer.isEmpty
          ? "You didn't say anything. This round counts as 0 points."
          : res["feedback"]?.toString() ?? "No feedback returned.";

      final metrics = _extractMetrics(res);
      final int roundScore = _extractRoundScore(res, success);

      totalScore += roundScore;

      if (success) {
        successfulRounds++;
      }

      roundResults.add({
        "round": currentRound,
        "prompt": prompt,
        "answer": userAnswer,
        "success": success,
        "score": roundScore,
        "feedback": feedback,
        "metrics": metrics,
      });

      final String nextPrompt = _extractNextPrompt(res);

      await _showRoundFeedbackDialog(
        success: success,
        feedback: feedback,
        roundScore: roundScore,
        metrics: metrics,
        isTimeout: isTimeout,
      );

      if (!mounted) return;

      if (currentRound >= totalRounds) {
        setState(() {
          isSubmitting = false;
        });

        await endGame();
      } else {
        setState(() {
          currentRound++;
          prompt = nextPrompt;
          recognizedText = "";
          timeLeft = roundDuration;
          isSubmitting = false;
        });

        startTimer();
      }
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

  Map<String, dynamic> _extractMetrics(Map<String, dynamic> response) {
    final metrics = response["metrics"];

    if (metrics is Map<String, dynamic>) {
      return metrics;
    }

    return {};
  }

  int _extractRoundScore(
      Map<String, dynamic> response,
      bool success,
      ) {
    final directScore = response["score"];

    if (directScore is num) {
      return directScore.round();
    }

    final roundScore = response["round_score"];

    if (roundScore is num) {
      return roundScore.round();
    }

    final metrics = response["metrics"];

    if (metrics is Map<String, dynamic>) {
      final metricScore = metrics["round_score"] ?? metrics["score"];

      if (metricScore is num) {
        return metricScore.round();
      }
    }

    return success ? 20 : 0;
  }

  String _extractNextPrompt(Map<String, dynamic> response) {
    final possibleKeys = [
      "next_prompt",
      "prompt",
      "next",
      "challenge",
    ];

    for (final key in possibleKeys) {
      final value = response[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return "React quickly in English.";
  }

  Future<void> _showRoundFeedbackDialog({
    required bool success,
    required String feedback,
    required int roundScore,
    required Map<String, dynamic> metrics,
    required bool isTimeout,
  }) async {
    String title;

    if (isTimeout) {
      title = "Time is up";
    } else if (success) {
      title = "Good reaction";
    } else {
      title = "Not quite";
    }

    final relevance = metrics["relevance"];
    final creativity = metrics["creativity"];
    final languageQuality =
        metrics["language_quality"] ?? metrics["languageQuality"];

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
            Expanded(child: Text(title)),
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
              if (relevance != null ||
                  creativity != null ||
                  languageQuality != null) ...[
                const SizedBox(height: 12),
                const Text(
                  "AI metrics:",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                if (relevance != null) Text("Relevance: $relevance"),
                if (creativity != null) Text("Creativity: $creativity"),
                if (languageQuality != null)
                  Text("Language quality: $languageQuality"),
              ],
              if (recognizedText.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  "Your answer:",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(recognizedText.trim()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(currentRound >= totalRounds ? "Finish" : "Next"),
          ),
        ],
      ),
    );
  }

  Future<void> endGame() async {
    timer?.cancel();

    int? backendFinalScore;
    String? finalFeedback;

    try {
      final res = await ApiService.endQuickReactions(gameId!);

      final rawScore = res["score"] ?? res["final_score"];

      if (rawScore is num) {
        backendFinalScore = rawScore.round();
      }

      finalFeedback = res["feedback"]?.toString() ??
          res["final_feedback"]?.toString() ??
          res["llm_feedback"]?.toString();

    } catch (_) {
      _showSnackBar("Final score could not be saved to leaderboard.");
    }

    if (!mounted) return;

    final finalScore = backendFinalScore ?? totalScore;
    final accuracy = (successfulRounds / totalRounds * 100).toStringAsFixed(0);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Your result"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Successful rounds: $successfulRounds/$totalRounds"),
              const SizedBox(height: 6),
              Text("Accuracy: $accuracy%"),
              const SizedBox(height: 6),
              Text("Final score: $finalScore pts"),
              if (finalFeedback != null && finalFeedback.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  "AI feedback:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(finalFeedback),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              startGame();
            },
            child: const Text("Restart"),
          ),
          TextButton(
            onPressed: () {
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
        title: const Text("Quick Reactions"),
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
                onPressed: startGame,
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
            "Your answer:",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty
                ? "Nothing recognized yet. Tap the microphone and answer quickly."
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
        title: Text("Round $currentRound/$totalRounds"),
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
              const SizedBox(height: 16),
              Text(
                "Time: $timeLeft",
                style: TextStyle(
                  fontSize: 22,
                  color: timeLeft <= 3 ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF0F172A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "React to this prompt:",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildTranscriptBox(),
              const SizedBox(height: 14),
              Text(
                recording
                    ? "Listening..."
                    : speechEnabled
                    ? "Tap mic and answer in English"
                    : "Speech recognition unavailable",
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 10),
              MicButton(
                recording: recording,
                onTap: () {
                  if (isSubmitting || isLoading) return;
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
                        : const Text("Reply"),
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