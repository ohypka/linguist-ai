import 'package:flutter/material.dart';

import '../../services/speech_service.dart';
import '../../widgets/mic_button.dart';

class SpeakingScreen extends StatefulWidget {
  final String topic;
  final String level;

  const SpeakingScreen({
    super.key,
    required this.topic,
    required this.level,
  });

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  final SpeechService speechService = SpeechService();

  bool speechEnabled = false;
  bool recording = false;
  bool isInitializing = true;

  String transcript = "";
  String result = "";

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  Future<void> initSpeech() async {
    try {
      speechEnabled = await speechService.init();
    } catch (_) {
      speechEnabled = false;
    }

    if (!mounted) return;

    setState(() {
      isInitializing = false;
    });
  }

  String get _prompt {
    final normalizedTopic = widget.topic.trim().toLowerCase();

    if (normalizedTopic == 'travel') {
      return 'Describe a place you would like to visit and explain why.';
    }

    if (normalizedTopic == 'food') {
      return 'Describe your favourite meal and explain what ingredients it has.';
    }

    if (normalizedTopic == 'work') {
      return 'Describe your ideal job and explain what you would like to do.';
    }

    if (normalizedTopic == 'school' || normalizedTopic == 'education') {
      return 'Describe your favourite subject and explain why you like it.';
    }

    if (normalizedTopic == 'health') {
      return 'Describe one healthy habit and explain why it is important.';
    }

    if (normalizedTopic == 'technology') {
      return 'Describe a useful app or device and explain how it helps people.';
    }

    return 'Speak for a short moment about the topic: ${widget.topic}.';
  }

  int get _wordCount {
    final text = transcript.trim();

    if (text.isEmpty) return 0;

    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  String _buildLocalFeedback() {
    if (transcript.trim().isEmpty) {
      return 'No speech detected yet.';
    }

    final words = _wordCount;

    if (words < 5) {
      return 'Very short answer. Try to say at least one full sentence.';
    }

    if (words < 15) {
      return 'Good start. Try to add more details to make your answer richer.';
    }

    return 'Nice answer length. You can now try to speak more fluently or add examples.';
  }

  Future<void> toggleRecording() async {
    if (isInitializing) return;

    if (!speechEnabled) {
      setState(() {
        result = 'Speech recognition is not available on this device.';
      });
      return;
    }

    try {
      if (!recording) {
        await speechService.startListening((text) {
          if (!mounted) return;

          setState(() {
            transcript = text;
            result = '';
          });
        });

        if (!mounted) return;

        setState(() {
          recording = true;
          result = '';
        });
      } else {
        await speechService.stopListening();

        if (!mounted) return;

        setState(() {
          recording = false;
          result = _buildLocalFeedback();
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        recording = false;
        result = 'Speech recognition error. Try again.';
      });
    }
  }

  Future<void> clearTranscript() async {
    if (recording) {
      await speechService.stopListening();
    }

    if (!mounted) return;

    setState(() {
      recording = false;
      transcript = '';
      result = '';
    });
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

  Widget _buildTranscriptBox() {
    final text = transcript.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your transcript:',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text.isEmpty
                ? 'Your speech transcript will appear here...'
                : text,
            style: TextStyle(
              fontSize: 17,
              color: text.isEmpty ? Colors.white38 : Colors.white,
              height: 1.35,
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Words: $_wordCount',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    speechService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canUseMic = speechEnabled && !isInitializing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speaking Mode'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Practice speaking',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildInfoChip(
                      icon: Icons.topic,
                      text: widget.topic,
                    ),
                    _buildInfoChip(
                      icon: Icons.school,
                      text: 'Level ${widget.level}',
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Speaking task:',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                if (isInitializing)
                  const CircularProgressIndicator()
                else
                  MicButton(
                    recording: recording,
                    onTap: () {
                      toggleRecording();
                    },
                  ),

                const SizedBox(height: 16),

                Text(
                  isInitializing
                      ? 'Preparing speech recognition...'
                      : recording
                      ? 'Listening... tap again to stop'
                      : canUseMic
                      ? 'Tap the microphone and speak in English'
                      : 'Speech recognition unavailable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 28),

                _buildTranscriptBox(),

                const SizedBox(height: 18),

                if (result.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      result,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: transcript.trim().isEmpty && !recording
                        ? null
                        : clearTranscript,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear transcript'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.25),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'This mode currently uses speech-to-text only. Full AI speaking evaluation can be added later with a backend endpoint.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}