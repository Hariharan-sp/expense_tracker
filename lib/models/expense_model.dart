import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Expense {
  String id;
  final bool isIncome;
  final String date; // "yyyy-MM-dd"
  final String category;
  final String description;
  final double amount;
  final String mode;
  final String userEmail;

  Expense({
    String? id,
    required this.isIncome,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.mode,
    required this.userEmail,
  }) : id = id ?? UniqueKey().toString();

  /// ---------------------------
  ///  Convert Google Sheet Row → Model
  /// ---------------------------
  factory Expense.fromRow(List<dynamic> row, String userEmail) {
    final dateStr = row.isNotEmpty ? row[0].toString().trim() : '';
    final category = row.length > 1 ? row[1].toString() : '';
    final description = row.length > 2 ? row[2].toString() : '';

    final amount = row.length > 3
        ? double.tryParse(row[3].toString().replaceAll(',', '')) ?? 0.0
        : 0.0;

    final mode = row.length > 4 ? row[4].toString() : '';

    // IMPORTANT: Read ID from Sheet (index 6)
    final id = row.length > 6 && row[6].toString().trim().isNotEmpty
        ? row[6].toString().trim()
        : UniqueKey().toString();

    // Parse date
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(dateStr).toLocal();
    } catch (_) {
      parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr, true).toLocal();
    }
    final isIncome =
        category.toLowerCase() == 'salary' || category.toLowerCase() == 'income';
    final dateIso = DateFormat('yyyy-MM-dd').format(parsedDate);

    return Expense(
      id: id,
      date: dateIso,
      category: category.isEmpty ? 'Misc' : category,
      description: description,
      amount: amount,
      mode: mode.isEmpty ? 'Cash' : mode,
      isIncome: isIncome,
      userEmail: userEmail,
    );
  }

  /// ---------------------------
  ///  Copy Model
  /// ---------------------------
  Expense copyWith({
    String? id,
    bool? isIncome,
    String? date,
    String? category,
    String? description,
    double? amount,
    String? mode,
    String? userEmail,
  }) {
    return Expense(
      id: id ?? this.id,
      isIncome: isIncome ?? this.isIncome,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  /// ---------------------------
  ///  JSON for Add / Update API
  /// ---------------------------
  Map<String, dynamic> toJson() => {
    'date': date,
    'category': category,
    'description': description,
    'amount': amount.toString(),
    'mode': mode,
    'isIncome': isIncome ? '1' : '0',
    'userEmail': userEmail,
  };

  /// ---------------------------
  ///  JSON for Update/Delete (includes ID)
  /// ---------------------------
  Map<String, dynamic> toJsonWithId() => {
    'id': id,
    'date': date,
    'category': category,
    'description': description,
    'amount': amount.toString(),
    'mode': mode,
    'isIncome': isIncome ? '1' : '0',
    'userEmail': userEmail,
  };
}
