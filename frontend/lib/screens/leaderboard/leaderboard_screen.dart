import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class LeaderboardScreen extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function(String) fetcher;

  const LeaderboardScreen({
    super.key,
    this.fetcher = ApiService.getLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            labelPadding: EdgeInsets.symmetric(horizontal: 8),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: Icon(Icons.style, size: 19),
                text: 'Cards',
              ),
              Tab(
                icon: Icon(Icons.block, size: 19),
                text: 'Forbidden',
              ),
              Tab(
                icon: Icon(Icons.bolt, size: 19),
                text: 'Quick',
              ),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: TabBarView(
            children: [
              _LeaderboardTab(
                gameType: 'cards',
                title: 'Grammar Cards',
                subtitle: 'Best grammar accuracy results',
                icon: Icons.style,
                fetcher: fetcher,
              ),
              _LeaderboardTab(
                gameType: 'forbidden_words',
                title: 'Forbidden Words',
                subtitle: 'Best word description scores',
                icon: Icons.block,
                fetcher: fetcher,
              ),
              _LeaderboardTab(
                gameType: 'quick_reactions',
                title: 'Quick Reactions',
                subtitle: 'Best quick speaking reaction scores',
                icon: Icons.bolt,
                fetcher: fetcher,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTab extends StatefulWidget {
  final String gameType;
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<List<Map<String, dynamic>>> Function(String) fetcher;

  const _LeaderboardTab({
    required this.gameType,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fetcher,
  });

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadLeaderboard();
  }

  Future<List<Map<String, dynamic>>> _loadLeaderboard() {
    return widget.fetcher(widget.gameType);
  }

  Future<void> _refreshLeaderboard() async {
    setState(() {
      _future = _loadLeaderboard();
    });

    await _future;
  }

  String _formatScore(int score) {
    if (widget.gameType == 'cards') {
      return '$score%';
    }

    return '$score pts';
  }

  IconData _rankIcon(int index) {
    switch (index) {
      case 0:
        return Icons.emoji_events;
      case 1:
        return Icons.workspace_premium;
      case 2:
        return Icons.military_tech;
      default:
        return Icons.person;
    }
  }

  Color _rankColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFFD700);
      case 1:
        return const Color(0xFFC0C0C0);
      case 2:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white70;
    }
  }

  String _extractNickname(Map<String, dynamic> entry) {
    final nickname = entry['nickname'] ?? entry['user_name'] ?? entry['name'];

    if (nickname == null || nickname.toString().trim().isEmpty) {
      return 'Unknown player';
    }

    return nickname.toString();
  }

  int _extractScore(Map<String, dynamic> entry) {
    final rawScore = entry['score'] ??
        entry['best_score'] ??
        entry['total_score'] ??
        entry['final_score'];

    if (rawScore is num) {
      return rawScore.round();
    }

    return 0;
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.indigoAccent.withOpacity(0.25),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard({
    required Map<String, dynamic> entry,
    required int index,
  }) {
    final rank = index + 1;
    final nickname = _extractNickname(entry);
    final score = _extractScore(entry);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: index < 3
            ? Colors.white.withOpacity(0.11)
            : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: index < 3
              ? _rankColor(index).withOpacity(0.45)
              : Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: _rankColor(index).withOpacity(0.16),
                  child: Icon(
                    _rankIcon(index),
                    color: _rankColor(index),
                    size: 22,
                  ),
                ),
                if (index >= 3)
                  Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.greenAccent.withOpacity(0.35),
              ),
            ),
            child: Text(
              _formatScore(score),
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshLeaderboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeader(),
          const SizedBox(height: 70),
          Icon(
            Icons.leaderboard_outlined,
            size: 68,
            color: Colors.white.withOpacity(0.35),
          ),
          const SizedBox(height: 16),
          const Text(
            'No scores yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Play this game first. The best results will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return RefreshIndicator(
      onRefresh: _refreshLeaderboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeader(),
          const SizedBox(height: 70),
          const Icon(
            Icons.error_outline,
            size: 68,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not load leaderboard',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: _refreshLeaderboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshLeaderboard,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }

          return _buildLeaderboardCard(
            entry: entries[index - 1],
            index: index - 1,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error!);
        }

        final entries = snapshot.data ?? [];

        return _buildLeaderboardList(entries);
      },
    );
  }
}