import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // emulator -> localhost mapping
  static const baseUrl = "http://10.0.2.2:8000";

  static Future<List<dynamic>> startCards(String topic) async {
    final res = await http.post(
      Uri.parse("$baseUrl/cards/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"topic": topic}),
    );

    // assumes backend returns a JSON list
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> scoreCards(
      String gameId, int correct, int total) async {
    final res = await http.post(
      Uri.parse("$baseUrl/cards/score"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "game_id": gameId,
        "correct": correct,
        "total": total,
      }),
    );

    return jsonDecode(res.body); // expected JSON object
  }

  static Future<Map<String, dynamic>> analyzeAudio(String path) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/audio/analyze"),
    );

    // send recorded file as multipart/form-data
    request.files.add(
      await http.MultipartFile.fromPath('file', path),
    );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();

    return jsonDecode(respStr); // parse API response
  }
}