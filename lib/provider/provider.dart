import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../models/expense_model.dart';
import '../services/google_sheet_services.dart';

class ExpenseProvider extends ChangeNotifier {
  final List<Expense> _expenses = [];
  bool _loading = false;
  String _error = '';
  String? _categoryFilter;

  List<Expense> get expenses =>
      _categoryFilter == null ? List.unmodifiable(_expenses) : List.unmodifiable(_expenses.where((e) => e.category == _categoryFilter));
  bool get loading => _loading;
  String get error => _error;
  String? get categoryFilter => _categoryFilter;

  Future<void> loadExpenses() async {
    _loading = true;
    _error = '';
    notifyListeners();
    try {
      final list = await GoogleSheetService.getExpenses();
      _expenses.clear();
      _expenses.addAll(list);
    } catch (e) {
      _error = 'Failed to load remote expenses';
      debugPrint(e.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense(Expense e) async {
    _loading = true;
    notifyListeners();
    final newExp = e.copyWith(id: UniqueKey().toString());
    _expenses.insert(0, newExp);
    notifyListeners();
    bool ok = false;
    try {
      ok = await GoogleSheetService.addExpense(newExp);
    } catch (e) {
      ok = false;
    }
    _loading = false;
    notifyListeners();
    return ok;
  }

  // ✅ FIXED: Send only the updated expense data with ID
  Future<void> updateExpense(Expense oldE, Expense newE) async {
    _loading = true;
    notifyListeners();

    try {
      // Send the new data with the old ID preserved
      final updatedExpense = newE.copyWith(id: oldE.id);
      await GoogleSheetService.updateExpense(updatedExpense);

      // Update local list
      final index = _expenses.indexWhere((x) => x.id == oldE.id);
      if (index != -1) {
        _expenses[index] = updatedExpense;
      }
    } catch (e) {
      _error = 'Failed to update expense';
      debugPrint(e.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ✅ FIXED: Send only the ID
  Future<void> deleteExpense(Expense e) async {
    _loading = true;
    notifyListeners();

    try {
      await GoogleSheetService.deleteExpense(e.id);

      // Remove from local list
      _expenses.removeWhere((x) => x.id == e.id);
    } catch (e) {
      _error = 'Failed to delete expense';
      debugPrint(e.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  List<Expense> filterByDateRange(DateTime from, DateTime to) {
    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final toStr = DateFormat('yyyy-MM-dd').format(to);

    return (_categoryFilter == null ? _expenses : _expenses.where((e) => e.category == _categoryFilter))
        .where((e) => e.date.compareTo(fromStr) >= 0 && e.date.compareTo(toStr) <= 0)
        .toList();
  }

  double sumRange(DateTime from, DateTime to, {bool? isIncome}) {
    return filterByDateRange(from, to)
        .where((e) => isIncome == null || e.isIncome == isIncome)
        .fold(0.0, (p, c) => p + c.amount);
  }

  Map<String, double> categorySums(DateTime from, DateTime to) {
    final map = <String, double>{};
    for (var e in filterByDateRange(from, to)) {
      if (!e.isIncome) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    return map;
  }

  List<String> get categories {
    final set = <String>{};
    for (var e in _expenses) set.add(e.category);
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int countForCategory(String category) {
    return _expenses.where((e) => e.category == category).length;
  }

  // Add these methods to your ExpenseProvider class

// Get transactions for a specific month
  List<Expense> getTransactionsForMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0); // Last day of the month

    final fromStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final toStr = DateFormat('yyyy-MM-dd').format(lastDay);

    return (_categoryFilter == null ? _expenses : _expenses.where((e) => e.category == _categoryFilter))
        .where((e) => e.date.compareTo(fromStr) >= 0 && e.date.compareTo(toStr) <= 0)
        .toList();
  }

// Get transactions for a specific day
  List<Expense> getTransactionsForDay(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    return (_categoryFilter == null ? _expenses : _expenses.where((e) => e.category == _categoryFilter))
        .where((e) => e.date == dateStr)
        .toList();
  }

// Get transactions for a specific week (Monday to Sunday)
  List<Expense> getTransactionsForWeek(DateTime anyDayInWeek) {
    final monday = anyDayInWeek.subtract(Duration(days: anyDayInWeek.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final fromStr = DateFormat('yyyy-MM-dd').format(monday);
    final toStr = DateFormat('yyyy-MM-dd').format(sunday);

    return (_categoryFilter == null ? _expenses : _expenses.where((e) => e.category == _categoryFilter))
        .where((e) => e.date.compareTo(fromStr) >= 0 && e.date.compareTo(toStr) <= 0)
        .toList();
  }

// Get all available months from expenses (for dropdown)
  List<DateTime> get availableMonths {
    final months = <DateTime>{};

    for (var expense in _expenses) {
      final dateParts = expense.date.split('-');
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        months.add(DateTime(year, month));
      }
    }

    return months.toList()..sort((a, b) => b.compareTo(a)); // Latest first
  }

// Get all available dates from expenses (for dropdown)
  List<DateTime> get availableDates {
    final dates = <DateTime>{};

    for (var expense in _expenses) {
      final dateParts = expense.date.split('-');
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        dates.add(DateTime(year, month, day));
      }
    }

    return dates.toList()..sort((a, b) => b.compareTo(a)); // Latest first
  }
}