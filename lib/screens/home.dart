import 'package:expense_tracker/screens/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/expense_model.dart';
import '../provider/provider.dart';
import 'add_expense.dart';
import 'filter_screen.dart';

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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddEditExpenseScreen()),
          );
        },
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add_rounded, size: 28),
      ),

      bottomNavigationBar: _buildBottomBar(),


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
            if(_tabIndex!=0) _buildHeader(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildFilterButtons(context),
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
    DateTime to;

    switch (_tabIndex) {
      case 0:
        from = DateTime(today.year, today.month, today.day, 0, 0, 0);
        to = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      case 1:
        final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
        from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        to = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      case 2:
        from = DateTime(today.year, today.month, 1);
        to = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      default:
        from = DateTime(1970);
        to = DateTime(today.year, today.month, today.day, 23, 59, 59);
    }

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

  Widget _bottomTabItem(String label, int index) {
    final bool active = index == _tabIndex;

    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF6366F1) : Colors.grey.shade600,
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 4,
                width: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
          ],
        ),
      ),
    );
  }


  Widget _buildBottomBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 12,
      child: Container(
        height: 70,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bottomTabItem("Day", 0),
            _bottomTabItem("Week", 1),
            const SizedBox(width: 40), // space for FAB
            _bottomTabItem("Month", 2),
            _bottomTabItem("All", 3),
          ],
        ),
      ),
    );
  }



  // Add this to your HomeScreen, for example in the app bar actions or in a new section
  Widget _buildFilterButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Visibility(
            visible:_tabIndex==0 ,
            child: Expanded(
              child: _buildFilterButton(
                context,
                'Day',
                Icons.calendar_today_rounded,
                Colors.blue,
                    () => _navigateToFilteredScreen(context, 'day'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Visibility(
            visible:_tabIndex==1 ,
            child: Expanded(
              child: _buildFilterButton(
                context,
                'Week',
                Icons.calendar_view_week_rounded,
                Colors.purple,
                    () => _navigateToFilteredScreen(context, 'week'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Visibility(
            visible:_tabIndex==2 ,
            child: Expanded(
              child: _buildFilterButton(
                context,
                'Month',
                Icons.calendar_view_month_rounded,
                Colors.orange,
                    () => _navigateToFilteredScreen(context, 'month'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFilteredScreen(BuildContext context, String filterType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilteredTransactionsScreen(filterType: filterType),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final prov = Provider.of<ExpenseProvider>(context);
    final today = DateTime.now();
    DateTime from;
    DateTime to;

    switch (_tabIndex) {
      case 0:
        from = DateTime(today.year, today.month, today.day);
        to = DateTime(today.year, today.month, today.day, );
        break;
      case 1:
        final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
        from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        to = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      case 2:
        from = DateTime(today.year, today.month, 1);
        to = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      default:
        from = DateTime(1970);
        to = DateTime(today.year, today.month, today.day, 23, 59, 59);
    }
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