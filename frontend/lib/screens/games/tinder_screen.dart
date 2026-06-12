import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TinderScreen extends StatefulWidget {
  final String topic;
  final String level;

  const TinderScreen({super.key, required this.topic, required this.level});

  @override
  State<TinderScreen> createState() => _TinderScreenState();
}

class _TinderScreenState extends State<TinderScreen> {
  List<dynamic> cards = [];
  String? gameId;

  bool isLoading = true;

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
    try {
      final response = await ApiService.startCards(widget.topic, level: widget.level);

      setState(() {
        gameId = response["game_id"] as String?;
        cards = response["cards"] as List<dynamic>;
        isLoading = false;
      });
    } catch (e) {
      print(e);

      setState(() {
        isLoading = false;
      });
    }
  }

  void resetPosition() {
    positionX = 0;
    positionY = 0;
    angle = 0;
  }

  void handleAnswer(bool userChoice) async {
    final card = cards[index];
    final isCorrect = card["is_correct"] as bool;
    final userWasCorrect = isCorrect == userChoice;

    _answers.add({
      "card_id": card["id"],
      "text": card["text"],
      "user_was_right": userWasCorrect,
    });

    if (userWasCorrect) {
      correct++;

      setState(() {
        showCorrectOverlay = true;
      });

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      setState(() {
        showCorrectOverlay = false;
      });
    } else {
      setState(() {
        showWrongOverlay = true;
      });

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      setState(() {
        showWrongOverlay = false;
      });
    }

    nextCard();
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
    final accuracy = (correct / cards.length * 100).toStringAsFixed(0);
    String feedback = '';
    int? score;

    try {
      final result = await ApiService.scoreCards(
        gameId: gameId!,
        topic: widget.topic,
        level: widget.level,
        answers: List<Map<String, dynamic>>.from(_answers),
      );
      feedback = result["llm_feedback"] as String? ?? '';
      score = result["score"] as int?;
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Your result"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Accuracy: $accuracy%"),
            if (score != null) Text("Score: $score pts"),
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(feedback),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                index = 0;
                correct = 0;
                gameId = null;
                _answers.clear();
                resetPosition();
                isLoading = true;
              });
              loadCards();
            },
            child: const Text("Restart"),
          ),
        ],
      ),
    );
  }

  void onDragUpdate(DragUpdateDetails details) {
    setState(() {
      positionX += details.delta.dx;
      positionY += details.delta.dy;
      angle = positionX / 300;
    });
  }

  void onDragEnd(DragEndDetails details) {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (cards.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("No cards available"),
        ),
      );
    }

    final card = cards[index];

    return Scaffold(
      appBar: AppBar(
        title: Text("Card ${index + 1}/${cards.length}"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onPanUpdate: onDragUpdate,
                onPanEnd: onDragEnd,
                child: Transform.translate(
                  offset: Offset(positionX, positionY),
                  child: Transform.rotate(
                    angle: angle,
                    child: Stack(
                      children: [
                        Container(
                          width:
                          MediaQuery.of(context).size.width *
                              0.85,
                          height:
                          MediaQuery.of(context).size.height *
                              0.6,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E293B),
                                Color(0xFF0F172A),
                              ],
                            ),
                            borderRadius:
                            BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 30,
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              card["text"],
                              style: const TextStyle(
                                fontSize: 24,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        // correct overlay
                        if (showCorrectOverlay)
                          Container(
                            width:
                            MediaQuery.of(context)
                                .size
                                .width *
                                0.85,
                            height:
                            MediaQuery.of(context)
                                .size
                                .height *
                                0.6,
                            decoration: BoxDecoration(
                              color:
                              Colors.green.withOpacity(0.8),
                              borderRadius:
                              BorderRadius.circular(30),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // wrong overlay
                        if (showWrongOverlay)
                          Container(
                            width:
                            MediaQuery.of(context)
                                .size
                                .width *
                                0.85,
                            height:
                            MediaQuery.of(context)
                                .size
                                .height *
                                0.6,
                            decoration: BoxDecoration(
                              color:
                              Colors.red.withOpacity(0.8),
                              borderRadius:
                              BorderRadius.circular(30),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.red,
                  size: 40,
                ),
                onPressed: () => handleAnswer(false),
              ),
              IconButton(
                icon: const Icon(
                  Icons.check,
                  color: Colors.green,
                  size: 40,
                ),
                onPressed: () => handleAnswer(true),
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
