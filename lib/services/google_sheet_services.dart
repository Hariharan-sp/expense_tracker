import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../models/expense_model.dart';

class GoogleSheetService {
  static const String apiUrl = kGoogleScriptUrl;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<List<Expense>> getExpenses() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final userEmail = user.email!;
    final url = '$apiUrl?userEmail=${Uri.encodeComponent(userEmail)}';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] != null) throw Exception(decoded['error']);
      if (decoded is List) {
        final rows = decoded.cast<List>();
        final data = <Expense>[];
        for (var i = 1; i < rows.length; i++) {
          data.add(Expense.fromRow(rows[i], userEmail));
        }
        return data;
      }
    }
    throw Exception('Failed to load expenses');
  }

  static Future<bool> addExpense(Expense expense) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final body = expense.toJson();

    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return json['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint('POST error: $e');
      return false;
    }
  }

  static Future<bool> updateExpense(Expense expense) async {
    try {
      debugPrint('=== UPDATE REQUEST ===');
      debugPrint('ID: ${expense.id}');

      final payload = expense.toJsonWithId();
      debugPrint('Payload: ${jsonEncode(payload)}');

      // Google Apps Script often only accepts POST, so we use POST with method=PUT
      final url = '$apiUrl?method=PUT';

      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      debugPrint('Status Code: ${res.statusCode}');
      debugPrint('Response Body: ${res.body}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        debugPrint('Decoded Response: $json');
        return json['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint('UPDATE error: $e');
      return false;
    }
  }

  // ✅ FIXED: Use POST with method parameter for DELETE
  static Future<bool> deleteExpense(String id) async {
    try {
      debugPrint('=== DELETE REQUEST ===');
      debugPrint('ID to delete: $id');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final payload = {
        "action": "delete",
        "id": id,
        "email": user.email,
      };

      debugPrint('Payload: ${jsonEncode(payload)}');

      final res = await http.post(
        Uri.parse(apiUrl), // <-- NO parameters
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      debugPrint('Status Code: ${res.statusCode}');
      debugPrint('Response Body: ${res.body}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return json['status'] == 'success';
      }

      return false;
    } catch (e) {
      debugPrint('DELETE error: $e');
      return false;
    }
  }

}