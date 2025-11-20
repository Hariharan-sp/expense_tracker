import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense_model.dart';
import '../provider/provider.dart';

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
      _catCtl.text = ""; // dropdown will show placeholder
      _modeCtl.text = "";
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
      category: _catCtl.text.trim(),
      description: _descCtl.text.trim(),
      amount: double.tryParse(_amtCtl.text.trim().replaceAll(',', '')) ?? 0.0,
      mode: _modeCtl.text.trim(),
      isIncome: _isIncome,
      userEmail: FirebaseAuth.instance.currentUser!.email!,
    );

    if (widget.existing == null) {
      await prov.addExpense(exp);
      ScaffoldMessenger.of(context).showSnackBar(
        successSnack("Transaction added successfully"),
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
      await prov.updateExpense(widget.existing!, updated);
      ScaffoldMessenger.of(context).showSnackBar(
        successSnack("Transaction updated successfully"),
      );
    }

    setState(() => _sending = false);

    if (mounted) Navigator.pop(context);
  }

  SnackBar successSnack(String msg) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Text(msg),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<ExpenseProvider>(context);

    // 🔥 Dynamic dropdown values from Spreadsheet
    final categories = prov.expenses.map((e) => e.category).toSet().toList();
    final modes = prov.expenses.map((e) => e.mode).toSet().toList();

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
            children: [
              _buildTypeToggle(),
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
              _buildTextOrDropdown(
                label: "Category",
                controller: _catCtl,
                icon: Icons.category_rounded,
                items: categories,
              ),
              // 🔽 CATEGORY DROPDOWN



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

              // 🔽 PAYMENT MODE DROPDOWN
              _buildTextOrDropdown(
                label: "Payment Mode",
                controller: _modeCtl,
                icon: Icons.payment_rounded,
                items: modes,
              ),


              const SizedBox(height: 32),

              _buildSubmitButton(),


            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transaction Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              Expanded(
                child: _toggleButton("Expense", !_isIncome, Colors.red.shade400,
                        () => setState(() => _isIncome = false)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _toggleButton("Income", _isIncome, Colors.green.shade400,
                        () => setState(() => _isIncome = true)),
              ),
            ],
          ),
        ),
      ],
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
                  ? (label == 'Income'
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded)
                  : (label == 'Income'
                  ? Icons.arrow_downward_outlined
                  : Icons.arrow_upward_outlined),
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

  Widget _buildTextOrDropdown({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required List<String> items,
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
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon, color: Color(0xFF6366F1)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) =>
              v == null || v.trim().isEmpty ? "Enter or select $label" : null,
            ),
          ),

          // Dropdown icon button
          Container(
            margin: const EdgeInsets.only(right: 6),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down, size: 32, color: Color(0xFF6366F1)),
              onSelected: (val) => controller.text = val,
              itemBuilder: (context) {
                return items
                    .map((e) => PopupMenuItem<String>(
                  value: e,
                  child: Text(e),
                ))
                    .toList();
              },
            ),
          ),
        ],
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Color(0xFF6366F1)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
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
    );
  }
}
