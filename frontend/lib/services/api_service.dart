import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return "$message (HTTP $statusCode)";
  }
}

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    }

    return "http://10.0.2.2:8000";

    // na fizycznym telefonie:
    // return "http://192.168.1.20:8000";
  }

  static const Duration _timeout = Duration(seconds: 45);
  static const String _nameKey = 'player_name';

  static String? _playerId;
  static String _playerName = "Guest";
  static bool _registered = false;

  static String get playerName => _playerName;

  static Future<void> init(String name) async {
    final trimmedName = name.trim();

    _playerName = trimmedName.isEmpty ? "Guest" : trimmedName;
    _playerId = await _loadOrCreatePlayerId();
    _registered = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _playerName);

    await ensureRegistered();
  }

  static Future<bool> tryAutoInit() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(_nameKey);
    if (savedName == null || savedName.isEmpty) return false;

    _playerName = savedName;
    _playerId = await _loadOrCreatePlayerId();
    _registered = false;

    try {
      await ensureRegistered();
    } catch (_) {

    }

    return true;
  }

  static Future<String> _loadOrCreatePlayerId() async {
    final prefs = await SharedPreferences.getInstance();

    final savedId = prefs.getString("device_id");

    if (savedId != null && savedId.trim().isNotEmpty) {
      return savedId;
    }

    final newId = const Uuid().v4();
    await prefs.setString("device_id", newId);

    return newId;
  }

  static Future<void> ensureRegistered() async {
    if (_registered && _playerId != null) return;

    _playerId ??= await _loadOrCreatePlayerId();

    final response = await http
        .post(
      Uri.parse("$baseUrl/auth/guest"),
      headers: _headers(includePlayerId: false),
      body: jsonEncode({
        "device_id": _playerId,
        "name": _playerName,
      }),
    )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(
          response.body,
          fallback: "Could not register guest user.",
        ),
        statusCode: response.statusCode,
      );
    }

    _registered = true;
  }

  static Map<String, String> _headers({
    bool includePlayerId = true,
  }) {
    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    if (includePlayerId) {
      final playerId = _playerId;

      if (playerId == null || playerId.trim().isEmpty) {
        throw const ApiException("Missing player ID.");
      }

      headers["X-Player-ID"] = playerId;
    }

    return headers;
  }

  static Future<Map<String, dynamic>> _postMap(
      String path, {
        Map<String, dynamic>? body,
        bool requiresAuth = true,
      }) async {
    if (requiresAuth) {
      await ensureRegistered();
    }

    try {
      final response = await http
          .post(
        Uri.parse("$baseUrl$path"),
        headers: _headers(includePlayerId: requiresAuth),
        body: jsonEncode(body ?? {}),
      )
          .timeout(_timeout);

      return _handleMapResponse(response);
    } on TimeoutException {
      throw const ApiException(
        "Request timed out. Check if the backend is running.",
      );
    } on http.ClientException catch (e) {
      throw ApiException("Network error: ${e.message}");
    } on FormatException {
      throw const ApiException("Backend returned invalid JSON.");
    }
  }

  static Future<List<Map<String, dynamic>>> _getList(
      String path, {
        Map<String, String>? queryParameters,
        bool requiresAuth = true,
      }) async {
    if (requiresAuth) {
      await ensureRegistered();
    }

    final uri = Uri.parse("$baseUrl$path").replace(
      queryParameters: queryParameters,
    );

    try {
      final response = await http
          .get(
        uri,
        headers: _headers(includePlayerId: requiresAuth),
      )
          .timeout(_timeout);

      return _handleListResponse(response);
    } on TimeoutException {
      throw const ApiException(
        "Request timed out. Check if the backend is running.",
      );
    } on http.ClientException catch (e) {
      throw ApiException("Network error: ${e.message}");
    } on FormatException {
      throw const ApiException("Backend returned invalid JSON.");
    }
  }

  static Map<String, dynamic> _handleMapResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(
          response.body,
          fallback: "Request failed.",
        ),
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException("Backend returned unexpected response format.");
  }

  static List<Map<String, dynamic>> _handleListResponse(
      http.Response response,
      ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(
          response.body,
          fallback: "Request failed.",
        ),
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    throw const ApiException("Backend returned unexpected response format.");
  }

  static String _extractErrorMessage(
      String responseBody, {
        required String fallback,
      }) {
    if (responseBody.trim().isEmpty) {
      return fallback;
    }

    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded["detail"];
        final message = decoded["message"];
        final error = decoded["error"];

        if (detail != null) {
          return detail.toString();
        }

        if (message != null) {
          return message.toString();
        }

        if (error != null) {
          return error.toString();
        }
      }
    } catch (_) {
      return responseBody;
    }

    return fallback;
  }

  static Future<Map<String, dynamic>> startCards(
      String topic, {
        String level = "B1",
      }) {
    return _postMap(
      "/cards/start",
      body: {
        "topic": topic,
        "level": level,
        "card_count": 10,
      },
    );
  }

  static Future<Map<String, dynamic>> scoreCards({
    required String gameId,
    required String topic,
    required String level,
    required List<Map<String, dynamic>> answers,
  }) {
    return _postMap(
      "/cards/score",
      body: {
        "game_id": gameId,
        "topic": topic,
        "level": level,
        "answers": answers,
      },
    );
  }

  static Future<Map<String, dynamic>> startForbiddenWords(
      String topic, {
        String level = "B1",
      }) {
    return _postMap(
      "/forbidden-words/start",
      body: {
        "topic": topic,
        "level": level,
      },
    );
  }

  static Future<Map<String, dynamic>> evaluateForbiddenWords({
    required String gameId,
    required String userText,
  }) {
    return _postMap(
      "/forbidden-words/evaluate",
      body: {
        "game_id": gameId,
        "user_text": userText,
      },
    );
  }

  static Future<void> endForbiddenWords(int totalScore) async {
    await _postMap(
      "/forbidden-words/end",
      body: {
        "total_score": totalScore,
      },
    );
  }

  static Future<Map<String, dynamic>> startQuickReactions({
    String topic = "general",
    String level = "B1",
  }) {
    return _postMap(
      "/quick-reactions/start",
      body: {
        "topic": topic,
        "level": level,
      },
    );
  }

  static Future<Map<String, dynamic>> evaluateQuickReactions({
    required String gameId,
    required String userText,
  }) {
    return _postMap(
      "/quick-reactions/evaluate",
      body: {
        "game_id": gameId,
        "user_text": userText,
      },
    );
  }

  static Future<Map<String, dynamic>> endQuickReactions(String gameId) {
    return _postMap(
      "/quick-reactions/end",
      body: {
        "game_id": gameId,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getLeaderboard(
      String gameType, {
        int limit = 10,
      }) {
    return _getList(
      "/leaderboard",
      queryParameters: {
        "game_type": gameType,
        "limit": limit.toString(),
      },
      requiresAuth: false,
    );
  }

  static Future<List<Map<String, dynamic>>> getHistory({
    String? gameType,
    int limit = 50,
  }) {
    final queryParameters = <String, String>{
      "limit": limit.toString(),
    };

    if (gameType != null && gameType.trim().isNotEmpty) {
      queryParameters["game_type"] = gameType;
    }

    return _getList(
      "/history",
      queryParameters: queryParameters,
    );
  }
}