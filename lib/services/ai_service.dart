import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiService {
  // ── PRODUCTION CONFIG ──
  // Set this to true and fill in your deployed backend's URL once it's live
  // (e.g. Render gives you something like https://your-app.onrender.com).
  // This is the ONE line you need to change after deploying — everything
  // else (Android emulator / iOS / web localhost fallbacks) still works for
  // local development when this is false.
  static const bool kUseProductionBackend = true;
  static const String kProductionBaseUrl = 'https://smart-inventory-ai-8oc7.onrender.com';

  static String getBaseUrl() {
    if (kUseProductionBackend) {
      return kProductionBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }

    return 'http://127.0.0.1:5000';
  }

  // ── JSON SANITIZATION ──
  // Firestore-derived maps carry Flutter-only types (DateTime, Color) that
  // jsonEncode cannot serialize. Encoding one throws immediately, which was
  // silently failing every /train and /report-live call and forcing a
  // fallback to the generic sample-data /report endpoint. These helpers
  // strip/convert those fields so the real data actually reaches the server.
  static dynamic _sanitizeValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is Color) return null; // dropped by _sanitizeMap below
    if (value is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Color) return; // skip non-serializable Color entirely
      result[key] = _sanitizeValue(value);
    });
    return result;
  }

  static List<Map<String, dynamic>> _sanitizeList(List<Map<String, dynamic>> list) {
    return list.map((item) => _sanitizeMap(item)).toList();
  }

  // ── Purana function — same raha ──
  static Future<Map<String, dynamic>> fetchReport() async {
    final uri = Uri.parse('${getBaseUrl()}/report');
    final client = http.Client();

    try {
      final response = await client
          .get(uri)
          // 45s, not 8s: free-tier hosts (e.g. Render's free plan) sleep
          // after inactivity and can take 30-60s to wake on the first
          // request. A short timeout here would make a perfectly healthy
          // deployed backend look "unreachable" on its first cold request.
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {};
      }
    } catch (e) {
      debugPrint('AI report fetch failed: $e');
    } finally {
      client.close();
    }

    return {};
  }

  // ── NAYA: Firebase ka real data bhejo, model retrain karo ──
  static Future<bool> trainWithRealData({
    required List<Map<String, dynamic>> inventory,
    required List<Map<String, dynamic>> expenses,
  }) async {
    final uri = Uri.parse('${getBaseUrl()}/train');
    final client = http.Client();

    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'inventory': _sanitizeList(inventory),
              'expenses': _sanitizeList(expenses),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('Model retrained: ${decoded['status']}');
        debugPrint('Items used: ${decoded['items_used']}');
        return true;
      } else {
        debugPrint('Train failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Train request failed: $e');
      return false;
    } finally {
      client.close();
    }
  }

  // ── NAYA: Real Firebase data ke saath live report lo ──
  static Future<Map<String, dynamic>> fetchLiveReport({
    required List<Map<String, dynamic>> inventory,
    required List<Map<String, dynamic>> expenses,
  }) async {
    final uri = Uri.parse('${getBaseUrl()}/report-live');
    final client = http.Client();

    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'inventory': _sanitizeList(inventory),
              'expenses': _sanitizeList(expenses),
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {};
      }
    } catch (e) {
      debugPrint('Live report fetch failed: $e');
    } finally {
      client.close();
    }

    return {};
  }
}