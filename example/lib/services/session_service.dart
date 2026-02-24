/// SessionService — persists form progress using SharedPreferences.
///
/// Saves and restores answered fields so users can resume
/// an interrupted form-filling session.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _prefix = 'speech2form_session_';

  /// Save form progress for a specific form ID.
  static Future<void> save({
    required String formId,
    required Map<String, dynamic> formData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(formData);
    await prefs.setString('$_prefix$formId', json);
    if (kDebugMode) print('💾 Session saved: ${formData.length} answers');
  }

  /// Load saved progress for a form. Returns null if none exists.
  static Future<Map<String, dynamic>?> load(String formId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_prefix$formId');
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      if (data.isEmpty) return null;
      if (kDebugMode) print('💾 Session loaded: ${data.length} answers');
      return data;
    } catch (e) {
      if (kDebugMode) print('💾 Session load error: $e');
      return null;
    }
  }

  /// Clear saved session for a form.
  static Future<void> clear(String formId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$formId');
    if (kDebugMode) print('💾 Session cleared');
  }

  /// Check if a saved session exists.
  static Future<bool> exists(String formId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_prefix$formId');
  }
}
