import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool isListening = false;
  String recognizedText = '';

  Future<bool> init() async {
    return await _speech.initialize();
  }

  Future<void> startListening(Function(String) onResult) async {
    isListening = true;

    await _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
        onResult(recognizedText);
      },
    );
  }

  Future<void> stopListening() async {
    isListening = false;
    await _speech.stop();
  }
}