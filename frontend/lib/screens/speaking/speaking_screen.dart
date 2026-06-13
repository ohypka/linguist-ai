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

  String _liveTranscript = "";
  String _savedTranscript = "";
  String result = "";

  int _taskIndex = 0;

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

  List<String> get _tasks {
    final normalizedTopic = widget.topic.trim().toLowerCase();

    if (normalizedTopic == 'travel') {
      return [
        'Describe a place you would like to visit and explain why.',
        'Talk about your last trip or holiday.',
        'Explain what you usually pack when you travel.',
        'Describe your dream vacation.',
        'Talk about a problem that can happen while travelling.',
      ];
    }

    if (normalizedTopic == 'food') {
      return [
        'Describe your favourite meal and explain what ingredients it has.',
        'Talk about a dish you can cook.',
        'Describe a restaurant you like.',
        'Explain what people usually eat in your country.',
        'Talk about healthy and unhealthy food.',
      ];
    }

    if (normalizedTopic == 'work') {
      return [
        'Describe your ideal job and explain what you would like to do.',
        'Talk about skills that are important at work.',
        'Describe a good team member.',
        'Explain what makes a workplace comfortable.',
        'Talk about a difficult situation at work.',
      ];
    }

    if (normalizedTopic == 'school' || normalizedTopic == 'education') {
      return [
        'Describe your favourite subject and explain why you like it.',
        'Talk about a teacher who helped you.',
        'Explain how you usually study for exams.',
        'Describe your typical school or university day.',
        'Talk about online learning.',
      ];
    }

    if (normalizedTopic == 'health') {
      return [
        'Describe one healthy habit and explain why it is important.',
        'Talk about how people can reduce stress.',
        'Explain what you do when you feel ill.',
        'Describe a healthy daily routine.',
        'Talk about why sleep is important.',
      ];
    }

    if (normalizedTopic == 'technology') {
      return [
        'Describe a useful app or device and explain how it helps people.',
        'Talk about how technology changes everyday life.',
        'Describe a website or app you use often.',
        'Explain the advantages and disadvantages of smartphones.',
        'Talk about how AI can help people learn.',
      ];
    }

    return [
      'Speak for a short moment about the topic: ${widget.topic}.',
      'Describe your opinion about ${widget.topic}.',
      'Give an example connected with ${widget.topic}.',
      'Explain why ${widget.topic} can be important.',
      'Talk about your experience with ${widget.topic}.',
    ];
  }

  String get _currentPrompt {
    final tasks = _tasks;

    if (tasks.isEmpty) {
      return 'Speak for a short moment in English.';
    }

    return tasks[_taskIndex % tasks.length];
  }

  String get _visibleTranscript {
    if (recording) {
      return _liveTranscript.trim();
    }

    if (_savedTranscript.trim().isNotEmpty) {
      return _savedTranscript.trim();
    }

    return _liveTranscript.trim();
  }

  int get _wordCount {
    final text = _visibleTranscript.trim();

    if (text.isEmpty) return 0;

    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  String _buildLocalFeedback() {
    final text = _visibleTranscript.trim();

    if (text.isEmpty) {
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

  void _moveToNextTask() {
    setState(() {
      _taskIndex = (_taskIndex + 1) % _tasks.length;
    });
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
        setState(() {
          _liveTranscript = '';
          _savedTranscript = '';
          result = '';
        });

        await speechService.startListening((text) {
          if (!mounted) return;

          setState(() {
            _liveTranscript = text;
          });
        });

        if (!mounted) return;

        setState(() {
          recording = true;
        });
      } else {
        await speechService.stopListening();

        if (!mounted) return;

        final finalText = _liveTranscript.trim();

        setState(() {
          recording = false;
          _savedTranscript = finalText;
          result = _buildLocalFeedback();
        });

        if (finalText.isNotEmpty) {
          _moveToNextTask();
        }
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
      _liveTranscript = '';
      _savedTranscript = '';
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
    final text = _visibleTranscript;

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
          Text(
            recording ? 'Live transcript:' : 'Last transcript:',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 180,
            ),
            child: SingleChildScrollView(
              child: Text(
                text.isEmpty
                    ? 'Your speech transcript will appear here...'
                    : text,
                style: TextStyle(
                  fontSize: 17,
                  color: text.isEmpty ? Colors.white38 : Colors.white,
                  height: 1.35,
                ),
              ),
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
    final tasks = _tasks;
    final totalTasks = tasks.length;
    final currentTaskNumber = totalTasks == 0
        ? 0
        : (_taskIndex % totalTasks) + 1;

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
                    _buildInfoChip(
                      icon: Icons.format_list_numbered,
                      text: 'Task $currentTaskNumber/$totalTasks',
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _currentPrompt,
                          key: ValueKey(_currentPrompt),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
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

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _visibleTranscript.trim().isEmpty &&
                            !recording
                            ? null
                            : clearTranscript,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: recording
                            ? null
                            : () {
                          clearTranscript();
                          _moveToNextTask();
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next task'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}