// lib/main.dart
import 'dart:convert';
import 'dart:ui';
import 'package:expense_tracker/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'auth_service.dart';
import 'login.dart';

// --------------------------
// Configuration
// --------------------------
const String kGoogleScriptUrl =
    "https://script.google.com/macros/s/AKfycbzbKhOjArb12rdZapYPot35WR8Gv09SYETFy2l5SR5HxJ4WQvs5dalVQFiXiDUM4durIg/exec";

// --------------------------
// Models
// --------------------------
class Expense {
  String id;
  final bool isIncome;
  final String date;
  final String category;
  final String description;
  final double amount;
  final String mode;
  final String userEmail; // NEW FIELD

  Expense({
    String? id,
    required this.isIncome,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.mode,
    required this.userEmail,   // ADD HERE
  }) : id = id ?? UniqueKey().toString();

  factory Expense.fromRow(List<dynamic> row, String userEmail) {
    try {
      final dateStr = row.length > 0 ? row[0].toString() : '';
      final category = row.length > 1 ? row[1].toString() : '';
      final description = row.length > 2 ? row[2].toString() : '';
      final amount = row.length > 3
          ? double.tryParse(row[3].toString().replaceAll(',', '')) ?? 0.0
          : 0.0;
      final mode = row.length > 4 ? row[4].toString() : '';
      bool? isIncome;
      if (row.length > 5) {
        final s = row[5].toString().toLowerCase();
        if (s == '1' || s == 'true' || s == 'yes') isIncome = true;
        if (s == '0' || s == 'false' || s == 'no') isIncome = false;
      }

      final parsedDate = _tryParseDate(dateStr) ?? DateTime.now();
      final dateIso = DateFormat('yyyy-MM-dd').format(parsedDate);

      final inferredIncome =
          isIncome ?? _inferIncomeFromText(category, description);

      return Expense(
        date: dateIso,
        category: category.isEmpty ? 'Misc' : category,
        description: description,
        amount: amount,
        mode: mode.isEmpty ? 'Cash' : mode,
        isIncome: inferredIncome,
        userEmail: userEmail,
      );
    } catch (_) {
      return Expense(
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        category: 'Misc',
        description: '',
        amount: 0.0,
        mode: 'Cash',
        isIncome: false,
        userEmail: userEmail,
      );
    }
  }

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

  Map<String, dynamic> toJson() => {
    'date': date,
    'category': category,
    'description': description,
    'amount': amount.toString(),
    'mode': mode,
    'isIncome': isIncome ? '1' : '0',
    'userEmail': userEmail,
  };
}


bool _inferIncomeFromText(String category, String description) {
  final combined = '${category.toLowerCase()} ${description.toLowerCase()}';
  const incomeWords = ['salary', 'income', 'credit', 'paid', 'received'];
  for (var w in incomeWords) {
    if (combined.contains(w)) return true;
  }
  return false;
}

DateTime? _tryParseDate(String s) {
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(s);
    } catch (_) {
      try {
        return DateFormat('dd-MM-yyyy').parseStrict(s);
      } catch (_) {
        try {
          return DateFormat('yyyy/MM/dd').parseStrict(s);
        } catch (_) {
          return null;
        }
      }
    }
  }
}

// --------------------------
// Service
// --------------------------
// class GoogleSheetService {
//   static const String apiUrl = kGoogleScriptUrl;
//
//   static Future<bool> addExpense(Expense expense) async {
//     final body = expense.toJson();
//     try {
//       final res = await http.post(Uri.parse(apiUrl),
//           headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
//       return res.statusCode == 200;
//     } catch (e) {
//       debugPrint('POST error: $e');
//       return false;
//     }
//   }
//
//   static Future<List<Expense>> getExpenses() async {
//     try {
//       final res = await http.get(Uri.parse(apiUrl));
//       if (res.statusCode == 200) {
//         final dynamic decoded = jsonDecode(res.body);
//         if (decoded is List) {
//           final rows = decoded.cast<dynamic>();
//           final data = <Expense>[];
//           for (var r in rows) {
//             if (r is List) {
//               final joined = r.join(' ').toLowerCase();
//               if (joined.contains('date') && joined.contains('amount')) continue;
//               data.add(Expense.fromRow(r));
//             } else if (r is Map) {
//               final date = r['date']?.toString() ?? r['Date']?.toString() ?? '';
//               final cat = r['category']?.toString() ?? r['Category']?.toString() ?? '';
//               final desc = r['description']?.toString() ?? r['Description']?.toString() ?? '';
//               final amt = r['amount']?.toString() ?? r['Amount']?.toString() ?? '0';
//               final mode = r['mode']?.toString() ?? r['Mode']?.toString() ?? '';
//               final maybeIsIncome = r['isIncome']?.toString() ?? r['IsIncome']?.toString();
//               final row = [date, cat, desc, amt, mode, maybeIsIncome];
//               data.add(Expense.fromRow(row));
//             }
//           }
//           return data.reversed.toList();
//         } else {
//           return [];
//         }
//       } else {
//         throw Exception('Status ${res.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('GET error: $e');
//       rethrow;
//     }
//   }
// }

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


// --------------------------
// Provider
// --------------------------
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
    return (_categoryFilter == null ? _expenses : _expenses.where((e) => e.category == _categoryFilter)).where((e) {
      final d = DateTime.parse(e.date);
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
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

// --------------------------
// UI
// --------------------------
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const ExpenseApp(),
    ),
  );
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... theme config
      home: AuthWrapper(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/profile': (_) => ProfileScreen(),
      },
    );
  }
}

// Auth wrapper to check login status
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenseProvider>(context, listen: false).loadExpenses();
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<ExpenseProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 110,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
          ),
        ),
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Account book',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              DateFormat('EEEE, MMM dd').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 14),
            // Profile row
            if (user != null) Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 16,
                  child: Text(
                    user.email![0].toUpperCase(),
                    style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  user.email!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                // Optionally add a sign-out button here
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: prov.loadExpenses,
            tooltip: 'Refresh',
          ),

          if (prov.categoryFilter != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.white),
              onPressed: () => prov.setCategoryFilter(null),
              tooltip: 'Clear filter',
            ),

          // 👉 NEW PROFILE BUTTON
          IconButton(
            icon: const Icon(Icons.person_rounded, color: Colors.white),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>  ProfileScreen()),
              );
            },
          ),

          const SizedBox(width: 7),
        ],

      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => AddEditExpenseScreen())),
        label: const Text('Add Transaction', style: TextStyle(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.error.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              prov.error,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: prov.loadExpenses,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_tabIndex != 0) _buildHeader(context),
            if (_tabIndex != 0) const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildTabs(),
                  const SizedBox(height: 20),
                  _buildContent(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );

  }


  Widget _buildHeader(BuildContext context) {
    final prov = Provider.of<ExpenseProvider>(context);
    final today = DateTime.now();
    DateTime from;
    switch (_tabIndex) {
      case 0:
        from = DateTime(today.year, today.month, today.day);
        break;
      case 1:
        final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
        from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        break;
      case 2:
        from = DateTime(today.year, today.month, 1);
        break;
      default:
        from = DateTime(1970);
    }
    final to = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final totalIncome = prov.sumRange(from, to, isIncome: true);
    final totalExpense = prov.sumRange(from, to, isIncome: false);
    final balance = totalIncome - totalExpense;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  'Total Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${NumberFormat('#,##,###').format(balance)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, color: Colors.greenAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Income',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${NumberFormat.compact().format(totalIncome)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.redAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${NumberFormat.compact().format(totalExpense)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(child: _tabButton('Today', 0)),
          Expanded(child: _tabButton('Week', 1)),
          Expanded(child: _tabButton('Month', 2)),
          Expanded(child: _tabButton('All', 3)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int idx) {
    final active = idx == _tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey.shade600,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final prov = Provider.of<ExpenseProvider>(context);
    final today = DateTime.now();
    DateTime from;
    switch (_tabIndex) {
      case 0:
        from = DateTime(today.year, today.month, today.day);
        break;
      case 1:
        final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
        from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        break;
      case 2:
        from = DateTime(today.year, today.month, 1);
        break;
      default:
        from = DateTime(1970);
    }
    final to = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final list = prov.filterByDateRange(from, to);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.isNotEmpty) ...[
          _CategoryChart(list),
          const SizedBox(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ExpenseList(expenses: list),
      ],
    );
  }
}

class AddEditExpenseScreen extends StatefulWidget {
  final Expense? existing;
  const AddEditExpenseScreen({Key? key, this.existing}) : super(key: key);

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateCtl = TextEditingController();
  final _catCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _amtCtl = TextEditingController();
  final _modeCtl = TextEditingController();
  bool _sending = false;
  bool _isIncome = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _dateCtl.text = e.date;
      _catCtl.text = e.category;
      _descCtl.text = e.description;
      _amtCtl.text = e.amount.toStringAsFixed(0);
      _modeCtl.text = e.mode;
      _isIncome = e.isIncome;
    } else {
      _dateCtl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _dateCtl.dispose();
    _catCtl.dispose();
    _descCtl.dispose();
    _amtCtl.dispose();
    _modeCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(_dateCtl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dateCtl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = Provider.of<ExpenseProvider>(context, listen: false);
    setState(() => _sending = true);
    final exp = Expense(
      date: _dateCtl.text,
      category: _catCtl.text.trim().isEmpty ? 'Misc' : _catCtl.text.trim(),
      description: _descCtl.text.trim(),
      amount: double.tryParse(_amtCtl.text.trim().replaceAll(',', '')) ?? 0.0,
      mode: _modeCtl.text.trim().isEmpty ? 'Cash' : _modeCtl.text.trim(),
      isIncome: _isIncome,
      userEmail: FirebaseAuth.instance.currentUser!.email!,
    );

    if (widget.existing == null) {
      await prov.addExpense(exp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Transaction added successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      final updated = widget.existing!.copyWith(
        date: exp.date,
        category: exp.category,
        description: exp.description,
        amount: exp.amount,
        mode: exp.mode,
        isIncome: exp.isIncome,
      );
      await prov.updateExpense(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Transaction updated successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    setState(() => _sending = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(widget.existing == null ? 'Add Transaction' : 'Edit Transaction'),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(child: _toggleButton('Expense', !_isIncome, Colors.red.shade400, () => setState(() => _isIncome = false))),
                    const SizedBox(width: 8),
                    Expanded(child: _toggleButton('Income', _isIncome, Colors.green.shade400, () => setState(() => _isIncome = true))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _dateCtl,
                label: 'Date',
                icon: Icons.calendar_today_rounded,
                readOnly: true,
                onTap: _pickDate,
                validator: (v) => v == null || v.isEmpty ? 'Select date' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _catCtl,
                label: 'Category',
                icon: Icons.category_rounded,
                hint: 'Food, Salary, Transport, etc.',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descCtl,
                label: 'Description',
                icon: Icons.description_rounded,
                hint: 'Optional notes',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _amtCtl,
                label: 'Amount',
                icon: Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _modeCtl,
                label: 'Payment Mode',
                icon: Icons.payment_rounded,
                hint: 'Cash, Card, UPI, etc.',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 2,
                  ),
                  child: _sending
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    'Save Transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleButton(String label, bool isActive, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive
                  ? (label == 'Income' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)
                  : (label == 'Income' ? Icons.arrow_downward_outlined : Icons.arrow_upward_outlined),
              color: isActive ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class ExpenseList extends StatelessWidget {
  final List<Expense> expenses;

  const ExpenseList({Key? key, required this.expenses}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<ExpenseProvider>(context, listen: false);

    if (expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              'Start adding your transactions',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      itemBuilder: (_, i) {
        final e = expenses[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: e.isIncome ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                e.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: e.isIncome ? Colors.green.shade600 : Colors.red.shade600,
                size: 22,
              ),
            ),
            title: Text(
              e.description.isNotEmpty ? e.description : e.category,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.category_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(e.category, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Icon(Icons.payment_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(e.mode, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM').format(DateTime.parse(e.date)),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${e.isIncome ? '+' : '-'}₹${NumberFormat('#,##,###').format(e.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: e.isIncome ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditExpenseScreen(existing: e),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.edit, size: 18),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete Transaction'),
                              content: const Text('Are you sure?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                  
                          if (ok == true) prov.deleteExpense(e.id);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.delete, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),


          ),
        );
      },
    );
  }
}

class _CategoryChart extends StatelessWidget {
  final List<Expense> expenses;

  const _CategoryChart(this.expenses, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (var e in expenses) {
      if (!e.isIncome) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    final items = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    if (items.isEmpty) return const SizedBox.shrink();

    final total = items.fold(0.0, (p, c) => p + c.value);
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF14B8A6)
    ];

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < items.length; i++) {
      final val = items[i].value;
      final perc = total == 0 ? 0.0 : (val / total) * 100;
      sections.add(PieChartSectionData(
        value: val,
        title: perc > 8 ? '${perc.toStringAsFixed(0)}%' : '',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        color: colors[i % colors.length],
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 3,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.take(5).map((e) {
                    final idx = items.indexOf(e);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: colors[idx % colors.length],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '₹${NumberFormat.compact().format(e.value)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
