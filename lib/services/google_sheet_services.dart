import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../models/expense_model.dart';

class GoogleSheetService {
  static const String apiUrl = kGoogleScriptUrl; // keep your script URL here
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Modified: Pass userEmail in GET query param
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
        for (var i = 1; i < rows.length; i++) { // skip headers
          data.add(Expense.fromRow(rows[i], userEmail));

        }
        return data;
      }
    }
    throw Exception('Failed to load expenses');
  }

  // Modified: Add userEmail in POST body
  static Future<bool> addExpense(Expense expense) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final body = expense.toJson(); // already contains userEmail

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

}