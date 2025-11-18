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

  Future<void> updateExpense(Expense updated) async {
    final idx = _expenses.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      _expenses[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
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
}