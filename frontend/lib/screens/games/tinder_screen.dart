import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../leaderboard/leaderboard_screen.dart';

class TinderScreen extends StatefulWidget {
  final String topic;
  final String level;

  const TinderScreen({
    super.key,
    required this.topic,
    required this.level,
  });

  @override
  State<TinderScreen> createState() => _TinderScreenState();
}

class _TinderScreenState extends State<TinderScreen> {
  List<dynamic> cards = [];
  String? gameId;

  bool isLoading = true;
  bool isAnswering = false;
  bool isSubmittingResult = false;

  String? errorMessage;

  int index = 0;
  int correct = 0;

  final List<Map<String, dynamic>> _answers = [];

  double positionX = 0;
  double positionY = 0;
  double angle = 0;

  bool showCorrectOverlay = false;
  bool showWrongOverlay = false;

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      cards = [];
      gameId = null;
      index = 0;
      correct = 0;
      isAnswering = false;
      isSubmittingResult = false;
      showCorrectOverlay = false;
      showWrongOverlay = false;
      _answers.clear();
      resetPosition();
    });

    try {
      final response = await ApiService.startCards(
        widget.topic,
        level: widget.level,
      );

      final loadedCards = List<dynamic>.from(
        response["cards"] as List<dynamic>? ?? [],
      )..shuffle(Random());

      if (!mounted) return;

      setState(() {
        gameId = response["game_id"] as String?;
        cards = loadedCards;
        isLoading = false;

        if (cards.isEmpty) {
          errorMessage = "No cards were generated. Try again.";
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = "Could not load grammar cards.\n$e";
      });
    }
  }

  void resetPosition() {
    positionX = 0;
    positionY = 0;
    angle = 0;
  }

  Future<void> handleAnswer(bool userChoice) async {
    if (isAnswering || isSubmittingResult || cards.isEmpty) return;
    if (index < 0 || index >= cards.length) return;

    setState(() {
      isAnswering = true;
    });

    final card = cards[index] as Map<String, dynamic>;
    final isCorrect = card["is_correct"] as bool;
    final userWasCorrect = isCorrect == userChoice;

    final explanation = card["explanation"]?.toString().trim();

    final feedbackText = explanation != null && explanation.isNotEmpty
        ? explanation
        : userWasCorrect
        ? "Correct answer."
        : "No explanation was returned for this card.";

    _answers.add({
      "card_id": card["id"],
      "text": card["text"],
      "user_was_right": userWasCorrect,
    });

    if (userWasCorrect) {
      correct++;
    }

    setState(() {
      showCorrectOverlay = userWasCorrect;
      showWrongOverlay = !userWasCorrect;
    });

    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;

    await _showAnswerExplanationDialog(
      wasCorrect: userWasCorrect,
      explanation: feedbackText,
    );

    if (!mounted) return;

    setState(() {
      showCorrectOverlay = false;
      showWrongOverlay = false;
      isAnswering = false;
    });

    nextCard();
  }

  Future<void> _showAnswerExplanationDialog({
    required bool wasCorrect,
    required String explanation,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              wasCorrect ? Icons.check_circle : Icons.cancel,
              color: wasCorrect ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(wasCorrect ? "Correct" : "Incorrect"),
          ],
        ),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void nextCard() {
    if (index < cards.length - 1) {
      setState(() {
        index++;
        resetPosition();
      });
    } else {
      _submitAndShowResult();
    }
  }

  Future<void> _submitAndShowResult() async {
    if (gameId == null) {
      _showSnackBar("Cannot submit result because game ID is missing.");
      return;
    }

    final accuracyValue = correct / cards.length * 100;
    final accuracy = accuracyValue.toStringAsFixed(0);

    String feedback = '';
    String? submitError;
    int? score;

    setState(() {
      isSubmittingResult = true;
    });

    try {
      final result = await ApiService.scoreCards(
        gameId: gameId!,
        topic: widget.topic,
        level: widget.level,
        answers: List<Map<String, dynamic>>.from(_answers),
      );

      feedback = result["llm_feedback"] as String? ?? '';

      final rawScore = result["score"];
      if (rawScore is num) {
        score = rawScore.round();
      }
    } catch (e) {
      submitError = "Result was calculated locally, but could not be saved.";
    }

    if (!mounted) return;

    setState(() {
      isSubmittingResult = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Your result"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Correct answers: $correct/${cards.length}"),
              const SizedBox(height: 6),
              Text("Accuracy: $accuracy%"),
              if (score != null) ...[
                const SizedBox(height: 6),
                Text("Score: $score pts"),
              ],
              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  "AI feedback:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(feedback),
              ],
              if (submitError != null) ...[
                const SizedBox(height: 14),
                Text(
                  submitError,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              loadCards();
            },
            child: const Text("Play again"),
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

  void onDragUpdate(DragUpdateDetails details) {
    if (isAnswering || isSubmittingResult) return;

    setState(() {
      positionX += details.delta.dx;
      positionY += details.delta.dy;

      final limitedPosition = positionX.clamp(-180.0, 180.0);
      angle = limitedPosition / 900;
    });
  }

  void onDragEnd(DragEndDetails details) {
    if (isAnswering || isSubmittingResult) return;

    if (positionX > 120) {
      handleAnswer(true);
    } else if (positionX < -120) {
      handleAnswer(false);
    } else {
      setState(() {
        resetPosition();
      });
    }
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
        title: const Text("Grammar Cards"),
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
                onPressed: loadCards,
                icon: const Icon(Icons.refresh),
                label: const Text("Try again"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> card) {
    final width = MediaQuery.of(context).size.width * 0.85;
    final height = MediaQuery.of(context).size.height * 0.52;

    return GestureDetector(
      onPanUpdate: onDragUpdate,
      onPanEnd: onDragEnd,
      child: Transform.translate(
        offset: Offset(positionX, positionY),
        child: Transform.rotate(
          angle: angle,
          child: Stack(
            children: [
              Container(
                width: width,
                height: height,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    card["text"]?.toString() ?? "",
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (showCorrectOverlay)
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (showWrongOverlay)
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                bottom: 18,
                child: Opacity(
                  opacity: 0.65,
                  child: Text(
                    "Swipe left: incorrect",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: Opacity(
                  opacity: 0.65,
                  child: Text(
                    "Swipe right: correct",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FloatingActionButton(
          heroTag: "wrong",
          backgroundColor: Colors.red,
          onPressed: isAnswering || isSubmittingResult
              ? null
              : () => handleAnswer(false),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 32,
          ),
        ),
        FloatingActionButton(
          heroTag: "correct",
          backgroundColor: Colors.green,
          onPressed: isAnswering || isSubmittingResult
              ? null
              : () => handleAnswer(true),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingView();
    }

    if (errorMessage != null || cards.isEmpty) {
      return _buildErrorView();
    }

    final card = cards[index] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text("Card ${index + 1}/${cards.length}"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "$correct correct",
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Decide if the sentence is grammatically correct.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: _buildCard(card),
                ),
              ),
              const SizedBox(height: 18),
              if (isSubmittingResult)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: CircularProgressIndicator(),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: _buildAnswerButtons(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}