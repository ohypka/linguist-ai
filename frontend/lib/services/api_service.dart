import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator localhost mapping
  // static const baseUrl = "http://10.0.2.2:8000";

  static const baseUrl = "http://127.0.0.1:8000";

  static const _playerId = "dev_player_1";
  static bool _registered = false;

  static Future<void> ensureRegistered() async {
    if (_registered) return;
    try {
      await http.post(
        Uri.parse("$baseUrl/auth/guest"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"device_id": _playerId, "name": "Guest"}),
      );
    } catch (_) {}
    _registered = true;
  }

  static Future<List<dynamic>> startCards(String topic) async {
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
      return jsonDecode(response.body);
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

  static Future<Map<String, dynamic>> startForbiddenWords(
      String topic) async {
    final res = await http.post(
      Uri.parse("$baseUrl/forbidden-words/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"topic": topic}),
    );

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> evaluateForbiddenWords({
    required String gameId,
    required String userText,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/forbidden-words/evaluate"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId,
      },
      body: jsonEncode({
        "game_id": gameId,
        "user_text": userText,
      }),
    );

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> startQuickReactions() async {
    final res = await http.post(
      Uri.parse("$baseUrl/quick-reactions/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({}),
    );

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> evaluateQuickReactions({
    required String gameId,
    required String userText,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/quick-reactions/evaluate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "game_id": gameId,
        "user_text": userText,
      }),
    );

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> endQuickReactions(String gameId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/quick-reactions/end"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId,
      },
      body: jsonEncode({"game_id": gameId}),
    );

    return jsonDecode(res.body);
  }
}