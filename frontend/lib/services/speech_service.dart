import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _available = false;
  String _latestRecognizedText = '';
  String _latestFinalText = '';

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

    _latestRecognizedText = '';
    _latestFinalText = '';

    await _speech.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 8),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.dictation,
      onResult: (result) {
        final text = result.recognizedWords.trim();

        if (text.isNotEmpty) {
          _latestRecognizedText = text;
          if (result.finalResult) {
            _latestFinalText = text;
          }
          onResult(text);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
  }

  bool get isListening => _speech.isListening;

  String get latestRecognizedText => _latestRecognizedText;

  String get latestFinalText => _latestFinalText;

  String get bestRecognizedText {
    if (_latestFinalText.trim().isNotEmpty) {
      return _latestFinalText.trim();
    }

    return _latestRecognizedText.trim();
  }
}
