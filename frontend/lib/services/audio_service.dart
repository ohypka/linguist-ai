import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class AudioService {
  final recorder = AudioRecorder();

  Future<String> start() async {
    final dir = await getTemporaryDirectory(); // temp storage for audio file
    final path = '${dir.path}/recording.m4a';

    await recorder.start(
      const RecordConfig(), // default recording settings
      path: path,
    );

    return path; // return file path for later use
  }

  Future<String?> stop() async {
    return await recorder.stop(); // returns path or null if failed
  }
}