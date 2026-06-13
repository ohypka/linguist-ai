import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ApiService {
  // Android emulator localhost mapping
  // static const baseUrl = "http://10.0.2.2:8000";

  static const baseUrl = "http://127.0.0.1:8000";

  static String? _playerId;
  static String _playerName = 'Guest';
  static bool _registered = false;

  static Future<void> init(String name) async {
    _playerName = name.trim().isEmpty ? 'Guest' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    _playerId = prefs.getString('device_id');
    if (_playerId == null) {
      _playerId = const Uuid().v4();
      await prefs.setString('device_id', _playerId!);
    }
    _registered = false;
    await ensureRegistered();
  }

  static Future<void> ensureRegistered() async {
    if (_registered) return;

    if (_playerId == null) {
      final prefs = await SharedPreferences.getInstance();
      _playerId = prefs.getString('device_id');

      if (_playerId == null) {
        _playerId = const Uuid().v4();
        await prefs.setString('device_id', _playerId!);
      }
    }

    try {
      final response = await http
          .post(
        Uri.parse("$baseUrl/auth/guest"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "device_id": _playerId,
          "name": _playerName,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          "Failed to register guest user. Status code: ${response.statusCode}",
        );
      }

      _registered = true;
    } on TimeoutException {
      throw Exception(
        "Backend is not responding. Check if the server is running.",
      );
    } catch (e) {
      throw Exception(
        "Could not connect to backend. Details: $e",
      );
    }
  }

  static Future<Map<String, dynamic>> startCards(String topic, {String level = 'B1'}) async {
    await ensureRegistered();
    final response = await http.post(
      Uri.parse("$baseUrl/cards/start"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId!,
      },
      body: jsonEncode({
        "topic": topic,
        "level": level,
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

  static Future<Map<String, dynamic>> scoreCards({
    required String gameId,
    required String topic,
    required String level,
    required List<Map<String, dynamic>> answers,
  }) async {
    await ensureRegistered();
    final response = await http.post(
      Uri.parse("$baseUrl/cards/score"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId!,
      },
      body: jsonEncode({
        "game_id": gameId,
        "topic": topic,
        "level": level,
        "answers": answers,
      }),
    );

    print("SCORE STATUS: ${response.statusCode}");
    print("SCORE BODY: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to submit score");
    }
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
      String topic, {String level = 'B1'}) async {
    await ensureRegistered();
    final res = await http.post(
      Uri.parse("$baseUrl/forbidden-words/start"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId!,
      },
      body: jsonEncode({"topic": topic, "level": level}),
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
        "X-Player-ID": _playerId!,
      },
      body: jsonEncode({
        "game_id": gameId,
        "user_text": userText,
      }),
    );

    return jsonDecode(res.body);
  }

  static Future<void> endForbiddenWords(int totalScore) async {
    await http.post(
      Uri.parse("$baseUrl/forbidden-words/end"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId!,
      },
      body: jsonEncode({"total_score": totalScore}),
    );
  }

  static Future<Map<String, dynamic>> startQuickReactions({String topic = 'general', String level = 'B1'}) async {
    await ensureRegistered();
    final res = await http.post(
      Uri.parse("$baseUrl/quick-reactions/start"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId!,
      },
      body: jsonEncode({"topic": topic, "level": level}),
    );

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> evaluateQuickReactions({
    required String gameId,
    required String userText,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/quick-reactions/evaluate"),
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId!,
      },
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
        "X-Player-ID": _playerId!,
      },
      body: jsonEncode({"game_id": gameId}),
    );

    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getHistory({
    String? gameType,
    int limit = 50,
  }) async {
    await ensureRegistered();

    final queryParameters = <String, String>{
      "limit": limit.toString(),
    };

    if (gameType != null && gameType.trim().isNotEmpty) {
      queryParameters["game_type"] = gameType;
    }

    final uri = Uri.parse("$baseUrl/history").replace(
      queryParameters: queryParameters,
    );

    final response = await http.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "X-Player-ID": _playerId!,
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }

      throw Exception("Invalid history response format");
    }

    throw Exception("Failed to load history");
  }

  static Future<List<Map<String, dynamic>>> getLeaderboard(String gameType) async {
    final response = await http.get(
      Uri.parse('$baseUrl/leaderboard?game_type=$gameType&limit=10'),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load leaderboard');
  }
}