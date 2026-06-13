import 'package:flutter/material.dart';

import '../../widgets/glass_card.dart';
import '../games/forbidden_words_screen.dart';
import '../games/quick_reactions_screen.dart';
import '../games/tinder_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../speaking/speaking_screen.dart';
import '../topic/topic_screen.dart';

class HomeScreen extends StatelessWidget {
  final String topic;
  final String level;

  const HomeScreen({
    super.key,
    required this.topic,
    required this.level,
  });

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _changeTopic(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TopicScreen()),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => _openScreen(context, screen),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicInfo(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Text(
            'Current lesson',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            topic,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(
                icon: Icons.school,
                text: 'Level $level',
              ),
              _buildInfoChip(
                icon: Icons.language,
                text: 'English',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _changeTopic(context),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Change topic or level'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardButton(BuildContext context) {
    return IconButton(
      tooltip: 'Leaderboard',
      icon: const Icon(
        Icons.leaderboard,
        color: Colors.white,
      ),
      onPressed: () => _openScreen(
        context,
        const LeaderboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Linguist AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a game mode and practice English with AI.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildTopicInfo(context),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context: context,
                      title: 'Grammar Cards',
                      subtitle: 'Decide if the sentence is correct or not.',
                      icon: Icons.style,
                      screen: TinderScreen(
                        topic: topic,
                        level: level,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGameCard(
                      context: context,
                      title: 'Forbidden Words',
                      subtitle: 'Describe a word without using banned words.',
                      icon: Icons.block,
                      screen: ForbiddenWordsScreen(
                        topic: topic,
                        level: level,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGameCard(
                      context: context,
                      title: 'Quick Reactions',
                      subtitle: 'Answer fast, creatively and in English.',
                      icon: Icons.bolt,
                      screen: QuickReactionsScreen(
                        topic: topic,
                        level: level,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGameCard(
                      context: context,
                      title: 'Speaking Mode',
                      subtitle: 'Practice speaking with speech recognition.',
                      icon: Icons.mic,
                      screen: SpeakingScreen(
                        topic: topic,
                        level: level,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _buildLeaderboardButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}