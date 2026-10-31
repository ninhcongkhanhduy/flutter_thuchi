import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cai_dat_chung.dart';
import 'menu_dieu_huong.dart';
import 'popup_giao_dich.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final DateTime? initialMonth;
  const TransactionHistoryScreen({super.key, this.initialMonth});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List allTransactions = [];
  List displayedTransactions = [];
  bool isLoading = true;
  late DateTime currentMonth;

  @override
  void initState() {
    super.initState();
    currentMonth = widget.initialMonth ?? DateTime.now();
    fetchTransactions();
  }

  void filterTransactions() {
    setState(() {
      displayedTransactions = allTransactions.where((tx) {
        if (tx['transaction_date'] == null) return false;
        DateTime txDate = DateTime.parse(tx['transaction_date'].toString());
        return txDate.month == currentMonth.month && txDate.year == currentMonth.year;
      }).toList();
    });
  }

  Future<void> fetchTransactions() async {
    if (currentUserId == null) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiUrl?action=get_transactions&user_id=$currentUserId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          allTransactions = data['data'];
          filterTransactions();
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteTransaction(int id, double amount) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa giao dịch này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final response = await http.post(
        Uri.parse('$apiUrl?action=delete_transaction'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id, 'user_id': currentUserId}),
      );
      if (response.statusCode == 200) {
        AppLog.add("Đã xóa giao dịch ID $id (Số tiền: ${formatCurrency(amount)} đ)");
        fetchTransactions();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void showTransactionDialog([Map? transaction]) {
    showDialog(context: context, builder: (context) => TransactionDialog(onSaved: fetchTransactions, transaction: transaction));
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: currentMonth, firstDate: DateTime(2000), lastDate: DateTime(2101),
    );
    if (picked != null && picked != currentMonth) {
      setState(() {
        currentMonth = picked;
        filterTransactions();
      });
    }
  }

  Widget buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, size: 30), onPressed: () { setState(() { currentMonth = DateTime(currentMonth.year, currentMonth.month - 1); filterTransactions(); }); }),
          InkWell(
            onTap: () => _selectDate(context),
            child: Row(
              children: [
                Text('Tháng ${currentMonth.month}/${currentMonth.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right, size: 30), onPressed: () { setState(() { currentMonth = DateTime(currentMonth.year, currentMonth.month + 1); filterTransactions(); }); }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết Thu Chi')),
      drawer: const AppDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                buildMonthSelector(),
                Expanded(
                  child: displayedTransactions.isEmpty
                      ? const Center(child: Text('Không có giao dịch nào.'))
                      : ListView.builder(
                          itemCount: displayedTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = displayedTransactions[index];
                            final isIncome = tx['type'] == 'INCOME';
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isIncome ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                  child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red),
                                ),
                                title: Text(tx['category_name'] ?? 'Không rõ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${tx['transaction_date']} ${tx['note'] != null && tx['note'].toString().isNotEmpty ? "- ${tx['note']}" : ""}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${isIncome ? '+' : '-'}${formatCurrency(tx['amount'])}', style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => showTransactionDialog(tx), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                    const SizedBox(width: 8),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.grey, size: 20), onPressed: () => deleteTransaction(int.parse(tx['id'].toString()), double.parse(tx['amount'].toString())), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTransactionDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}