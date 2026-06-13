import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const String allGames = "all";

  String selectedGameType = allGames;
  late Future<List<Map<String, dynamic>>> historyFuture;

  @override
  void initState() {
    super.initState();
    historyFuture = _loadHistory();
  }

  Future<List<Map<String, dynamic>>> _loadHistory() {
    return ApiService.getHistory(
      gameType: selectedGameType == allGames ? null : selectedGameType,
    );
  }

  Future<void> _refreshHistory() async {
    setState(() {
      historyFuture = _loadHistory();
    });

    await historyFuture;
  }

  void _changeFilter(String gameType) {
    setState(() {
      selectedGameType = gameType;
      historyFuture = _loadHistory();
    });
  }

  String _gameTitle(String gameType) {
    switch (gameType) {
      case "cards":
        return "Grammar Cards";
      case "forbidden_words":
        return "Forbidden Words";
      case "quick_reactions":
        return "Quick Reactions";
      default:
        return gameType;
    }
  }

  IconData _gameIcon(String gameType) {
    switch (gameType) {
      case "cards":
        return Icons.style;
      case "forbidden_words":
        return Icons.block;
      case "quick_reactions":
        return Icons.bolt;
      default:
        return Icons.history;
    }
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return "Unknown date";

    final value = rawDate.toString();

    try {
      final date = DateTime.parse(value).toLocal();

      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, "0");
      final minute = date.minute.toString().padLeft(2, "0");

      return "$day.$month.$year, $hour:$minute";
    } catch (_) {
      return value;
    }
  }

  String _extractFeedback(Map<String, dynamic> entry) {
    final feedback = entry["llm_feedback"];

    if (feedback is String && feedback.trim().isNotEmpty) {
      return feedback;
    }

    if (feedback is Map<String, dynamic>) {
      final possibleKeys = [
        "feedback",
        "final_feedback",
        "llm_feedback",
      ];

      for (final key in possibleKeys) {
        final value = feedback[key];

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }

      final roundFeedback = feedback["round_feedback"];

      if (roundFeedback is List && roundFeedback.isNotEmpty) {
        return roundFeedback.last.toString();
      }
    }

    return "No feedback available.";
  }

  int? _extractScore(Map<String, dynamic> entry) {
    final metrics = entry["metrics"];

    if (metrics is Map<String, dynamic>) {
      final directScore = metrics["score"] ??
          metrics["final_score"] ??
          metrics["total_score"] ??
          metrics["round_score"];

      if (directScore is num) {
        return directScore.round();
      }

      final scoreBreakdown = metrics["score_breakdown"];

      if (scoreBreakdown is Map<String, dynamic>) {
        final score = scoreBreakdown["final_score"] ??
            scoreBreakdown["score"] ??
            scoreBreakdown["total_score"];

        if (score is num) {
          return score.round();
        }
      }
    }

    return null;
  }

  String _extractDetails(Map<String, dynamic> entry) {
    final metrics = entry["metrics"];

    if (metrics is Map<String, dynamic>) {
      final scoreBreakdown = metrics["score_breakdown"];

      if (scoreBreakdown is Map<String, dynamic>) {
        final accuracy = scoreBreakdown["accuracy"];
        final correctAnswers = scoreBreakdown["correct_answers"];
        final totalCards = scoreBreakdown["total_cards"];
        final successCount = scoreBreakdown["success_count"];
        final roundsPlayed = scoreBreakdown["rounds_played"];

        if (accuracy != null &&
            correctAnswers != null &&
            totalCards != null) {
          return "Accuracy: $accuracy% • Correct: $correctAnswers/$totalCards";
        }

        if (successCount != null && roundsPlayed != null) {
          return "Successful rounds: $successCount/$roundsPlayed";
        }
      }

      final lowEffort = metrics["low_effort"];

      if (lowEffort == true) {
        return "Low effort answer";
      }
    }

    final answers = entry["user_answers"];

    if (answers is List) {
      return "Answers: ${answers.length}";
    }

    if (answers is Map<String, dynamic>) {
      final userText = answers["user_text"] ?? answers["fallback_text"];

      if (userText != null && userText.toString().trim().isNotEmpty) {
        return "Answer: ${userText.toString()}";
      }
    }

    return "Details unavailable";
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
  }) {
    final selected = selectedGameType == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _changeFilter(value),
      selectedColor: Colors.indigoAccent.withOpacity(0.35),
      backgroundColor: Colors.white.withOpacity(0.08),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected
            ? Colors.indigoAccent.withOpacity(0.6)
            : Colors.white.withOpacity(0.12),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final gameType = entry["game_type"]?.toString() ?? "unknown";
    final topic = entry["topic"]?.toString() ?? "general";
    final level = entry["level"]?.toString() ?? "-";
    final endedAt = _formatDate(entry["ended_at"]);
    final feedback = _extractFeedback(entry);
    final score = _extractScore(entry);
    final details = _extractDetails(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.indigoAccent.withOpacity(0.25),
                child: Icon(
                  _gameIcon(gameType),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gameTitle(gameType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$topic • Level $level",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    "$score pts",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            endedAt,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            details,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Feedback:",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            feedback,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.white.withOpacity(0.35),
            ),
            const SizedBox(height: 16),
            const Text(
              "No history yet",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Play a game first. Your results and AI feedback will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              "Could not load history",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _refreshHistory,
              icon: const Icon(Icons.refresh),
              label: const Text("Try again"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          return _buildHistoryCard(entries[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: "All",
                    value: allGames,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: "Cards",
                    value: "cards",
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: "Forbidden",
                    value: "forbidden_words",
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: "Quick",
                    value: "quick_reactions",
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error!);
                  }

                  final entries = snapshot.data ?? [];

                  return _buildHistoryList(entries);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}