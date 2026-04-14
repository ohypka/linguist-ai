import 'package:flutter/material.dart';
import 'dart:math';

class TinderScreen extends StatefulWidget {
  const TinderScreen({super.key});

  @override
  State<TinderScreen> createState() => _TinderScreenState();
}

class _TinderScreenState extends State<TinderScreen> {
  final List<Map<String, dynamic>> cards = [
    {
      "sentence": "She go to school every day",
      "is_correct": false,
      "explanation": "Should be: 'She goes' (3rd person singular)"
    },
    {
      "sentence": "I have finished my homework",
      "is_correct": true,
      "explanation": "Correct use of Present Perfect"
    },
    {
      "sentence": "He don’t like coffee",
      "is_correct": false,
      "explanation": "Should be: 'He doesn't like coffee'"
    },
    {
      "sentence": "They were playing football yesterday",
      "is_correct": true,
      "explanation": "Correct Past Continuous"
    },
    {
      "sentence": "I am agree with you",
      "is_correct": false,
      "explanation": "Should be: 'I agree with you'"
    },
  ];

  int index = 0;
  int correct = 0;

  double positionX = 0;
  double positionY = 0;
  double angle = 0; // rotation based on horizontal drag

  bool showCorrectOverlay = false;

  void resetPosition() {
    positionX = 0;
    positionY = 0;
    angle = 0; // reset after swipe or restart
  }

  void handleAnswer(bool userChoice) async {
    final card = cards[index];
    final isCorrect = card["is_correct"];
    final explanation = card["explanation"];

    bool userWasCorrect = isCorrect == userChoice;

    if (userWasCorrect) {
      correct++;

      setState(() {
        showCorrectOverlay = true; // show quick success feedback
      });

      await Future.delayed(const Duration(milliseconds: 700));

      setState(() {
        showCorrectOverlay = false;
      });

      nextCard();
    } else {
      // show explanation only on wrong answer
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Wrong!!!"),
          content: Text(
            explanation,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Next"),
            )
          ],
        ),
      );

      nextCard();
    }
  }

  void nextCard() {
    if (index < cards.length - 1) {
      setState(() {
        index++;
        resetPosition(); // important: avoid tilted next card
      });
    } else {
      final accuracy = (correct / cards.length * 100).toStringAsFixed(0);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Your result"),
          content: Text("Accuracy: $accuracy%"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  index = 0;
                  correct = 0;
                  resetPosition(); // important on restart
                });
              },
              child: const Text("Restart"),
            )
          ],
        ),
      );
    }
  }

  void onDragUpdate(DragUpdateDetails details) {
    setState(() {
      positionX += details.delta.dx;
      positionY += details.delta.dy;
      angle = positionX / 300; // small tilt effect
    });
  }

  void onDragEnd(DragEndDetails details) {
    // threshold to decide swipe direction
    if (positionX > 120) {
      handleAnswer(true);
    } else if (positionX < -120) {
      handleAnswer(false);
    } else {
      setState(() {
        resetPosition(); // snap back if not far enough
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: MediaQuery.of(context).size.height * 0.6,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E293B),
                                Color(0xFF0F172A)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 30,
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              card["sentence"],
                              style: const TextStyle(fontSize: 24),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        // overlay shown only for correct answers
                        if (showCorrectOverlay)
                          Container(
                            width:
                            MediaQuery.of(context).size.width * 0.85,
                            height:
                            MediaQuery.of(context).size.height * 0.6,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Center(
                              child: Icon(Icons.check,
                                  size: 80, color: Colors.white),
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.red, size: 40),
                onPressed: () => handleAnswer(false),
              ),
              IconButton(
                icon: const Icon(Icons.check,
                    color: Colors.green, size: 40),
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