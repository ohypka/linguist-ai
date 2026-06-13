import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _available = false;

  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (error) {
        print('Speech error: $error');
      },
      onStatus: (status) {
        print('Speech status: $status');
      },
    );

    return _available;
  }

  Future<void> startListening(
      Function(String text) onResult,
      ) async {
    if (!_available) return;

    await _speech.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.dictation,
      onResult: (result) {
        final text = result.recognizedWords.trim();

        if (text.isNotEmpty) {
          onResult(text);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
  }

  bool get isListening => _speech.isListening;
}