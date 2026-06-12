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
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 12),
            tabs: [
              Tab(text: 'Cards'),
              Tab(text: 'Forbidden Words'),
              Tab(text: 'Quick Reactions'),
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
              _LeaderboardTab(gameType: 'cards', fetcher: fetcher),
              _LeaderboardTab(gameType: 'forbidden_words', fetcher: fetcher),
              _LeaderboardTab(gameType: 'quick_reactions', fetcher: fetcher),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTab extends StatefulWidget {
  final String gameType;
  final Future<List<Map<String, dynamic>>> Function(String) fetcher;

  const _LeaderboardTab({required this.gameType, required this.fetcher});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher(widget.gameType);
  }

  String _formatScore(int score) {
    if (widget.gameType == 'cards') return '$score%';
    return '$score pts';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load leaderboard.'));
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return const Center(child: Text('No scores yet.'));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              leading: Text(
                '#${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              title: Text(entry['nickname'] as String? ?? 'Unknown'),
              trailing: Text(_formatScore((entry['score'] as num?)?.toInt() ?? 0)),
            );
          },
        );
      },
    );
  }
}
