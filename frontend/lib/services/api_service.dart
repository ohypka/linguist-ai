import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator localhost mapping
  // static const baseUrl = "http://10.0.2.2:8000";

  static const baseUrl = "http://10.0.2.2:8000";

  static Future<Map<String, dynamic>> startCards(String topic) async {
    final response = await http.post(
      Uri.parse("$baseUrl/cards/start"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "topic": topic,
        "card_count": 10,
      }),
    );

    print("START CARDS STATUS: ${response.statusCode}");
    print("START CARDS BODY: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to load cards");
    }
  }

  static Future<Map<String, dynamic>> scoreCards(
      String gameId,
      int correct,
      int total,
      ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/cards/score"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "game_id": gameId,
        "correct": correct,
        "total": total,
      }),
    );

    print("SCORE STATUS: ${response.statusCode}");
    print("SCORE BODY: ${response.body}");

    return jsonDecode(response.body);
  }

  // kept temporarily for compatibility with previous flow
  static Future<Map<String, dynamic>> analyzeAudio(
      String path,
      ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/audio/analyze"),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        path,
      ),
    );

    final response = await request.send();
    final respStr =
    await response.stream.bytesToString();

    print("AUDIO RESPONSE: $respStr");

    return jsonDecode(respStr);
  }
}
