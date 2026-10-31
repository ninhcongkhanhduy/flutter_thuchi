import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cai_dat_chung.dart';
import 'menu_dieu_huong.dart';
import 'man_hinh_chi_tiet.dart';
import 'popup_giao_dich.dart';

class PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  PieChartPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    double total = values.fold(0, (sum, val) => sum + val);
    if (total == 0) return;
    double startAngle = -pi / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List allTransactions = [];
  List displayedTransactions = [];
  bool isLoading = true;
  DateTime currentMonth = DateTime.now();
  
  double monthlyBudget = 0;
  double totalIncome = 0;
  double totalExpense = 0;
  bool hasWarnedThisMonth = false;

  @override
  void initState() {
    super.initState();
    _loadBudget();
    fetchTransactions();
  }

  Future<void> _loadBudget() async {
    if (currentUserId == null) return;
    try {
      final response = await http.get(Uri.parse('$apiUrl?action=get_budget&user_id=$currentUserId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            monthlyBudget = double.parse(data['budget'].toString());
          });
          _checkBudgetWarning();
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải ngân sách: $e');
    }
  }

  Future<void> _setBudget(double val) async {
    if (currentUserId == null) return;
    
    setState(() {
      monthlyBudget = val;
      hasWarnedThisMonth = false;
    });
    _checkBudgetWarning();

    try {
      await http.post(
        Uri.parse('$apiUrl?action=update_budget'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': currentUserId,
          'budget': val,
        }),
      );
      AppLog.add("Đã thay đổi ngân sách tháng thành ${formatCurrency(val)} đ");
    } catch (e) {
      debugPrint('Lỗi lưu ngân sách: $e');
    }
  }

  void _checkBudgetWarning() {
    if (monthlyBudget > 0 && totalExpense > monthlyBudget && !hasWarnedThisMonth) {
      hasWarnedThisMonth = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBudgetExceededNotification();
      });
    }
  }

  void _showBudgetExceededNotification() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Vượt ngân sách!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Tháng này bạn đã chi tiêu ${formatCurrency(totalExpense)} đ, vượt mức ngân sách đã thiết lập (${formatCurrency(monthlyBudget)} đ).\n\nHãy cân đối lại chi tiêu nhé!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog() {
    final TextEditingController controller = TextEditingController(
      text: monthlyBudget > 0 ? monthlyBudget.toStringAsFixed(0) : ''
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thiết lập ngân sách tháng'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Số tiền giới hạn (VNĐ)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              double val = double.tryParse(controller.text) ?? 0;
              _setBudget(val);
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          )
        ],
      ),
    );
  }

  void filterTransactions() {
    setState(() {
      displayedTransactions = allTransactions.where((tx) {
        if (tx['transaction_date'] == null) return false;
        DateTime txDate = DateTime.parse(tx['transaction_date'].toString());
        return txDate.month == currentMonth.month && txDate.year == currentMonth.year;
      }).toList();

      totalIncome = 0;
      totalExpense = 0;
      for (var tx in displayedTransactions) {
        double amount = double.parse(tx['amount'].toString());
        if (tx['type'] == 'INCOME') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }
      
      _checkBudgetWarning();
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

  void showTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => TransactionDialog(onSaved: fetchTransactions),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != currentMonth) {
      setState(() {
        currentMonth = picked;
        hasWarnedThisMonth = false;
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
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 30),
            onPressed: () {
              setState(() {
                currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                hasWarnedThisMonth = false;
                filterTransactions();
              });
            },
          ),
          InkWell(
            onTap: () => _selectDate(context),
            child: Row(
              children: [
                Text(
                  'Tháng ${currentMonth.month}/${currentMonth.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 30),
            onPressed: () {
              setState(() {
                currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                hasWarnedThisMonth = false;
                filterTransactions();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildBudgetWarning(double totalExpense) {
    if (monthlyBudget <= 0) return const SizedBox.shrink();
    
    double percent = totalExpense / monthlyBudget;
    bool isExceeded = percent > 1.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: isExceeded ? Colors.red.shade50 : Colors.blue.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), 
        side: BorderSide(color: isExceeded ? Colors.red : Colors.blue.shade200)
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ngân sách tháng:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(formatCurrency(monthlyBudget), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent > 1.0 ? 1.0 : percent,
              backgroundColor: Colors.grey.shade300,
              color: isExceeded ? Colors.red : Colors.blue,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            if (isExceeded)
              const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Expanded(child: Text('Cảnh báo: Bạn đã chi tiêu vượt quá ngân sách!', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))),
                ],
              )
            else
              Text('Còn lại: ${formatCurrency(monthlyBudget - totalExpense)}', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }

  Widget buildSummary(double totalIncome, double totalExpense) {
    double balance = totalIncome - totalExpense;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thu nhập', style: TextStyle(color: Colors.green, fontSize: 14)),
                const SizedBox(height: 4),
                Text('+${formatCurrency(totalIncome)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chi tiêu', style: TextStyle(color: Colors.red, fontSize: 14)),
                const SizedBox(height: 4),
                Text('-${formatCurrency(totalExpense)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Số dư', style: TextStyle(color: Colors.blue, fontSize: 14)),
                const SizedBox(height: 4),
                Text(formatCurrency(balance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, double value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
        Text(formatCurrency(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget buildIncomeExpensePieChart(double income, double expense) {
    if (income == 0 && expense == 0) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text('Chưa có dữ liệu thu chi tháng này.', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tỷ trọng Thu - Chi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(painter: PieChartPainter([income, expense], [Colors.green, Colors.red])),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Thu nhập', income, Colors.green),
                      const SizedBox(height: 10),
                      _buildLegendItem('Chi tiêu', expense, Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildExpenseBarChart() {
    Map<String, double> expenseData = {};
    for (var tx in displayedTransactions) {
      if (tx['type'] == 'EXPENSE') {
        String catName = tx['category_name'] ?? 'Khác';
        double amount = double.parse(tx['amount'].toString());
        expenseData[catName] = (expenseData[catName] ?? 0) + amount;
      }
    }
    if (expenseData.isEmpty) return const SizedBox.shrink();

    double maxVal = expenseData.values.reduce(max);
    final colors = [Colors.redAccent, Colors.orangeAccent, Colors.blueAccent, Colors.teal, Colors.purpleAccent, Colors.amber, Colors.pinkAccent];
    int colorIndex = 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Biểu đồ Chi tiêu theo danh mục', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: expenseData.entries.map((entry) {
                  double height = maxVal == 0 ? 0 : (entry.value / maxVal) * 120;
                  Color barColor = colors[colorIndex % colors.length];
                  colorIndex++;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(formatCurrency(entry.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          width: 35,
                          height: height > 0 ? height : 1,
                          decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 60,
                          child: Text(entry.key, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          IconButton(icon: const Icon(Icons.account_balance_wallet), tooltip: 'Thiết lập ngân sách', onPressed: _showBudgetDialog),
        ],
      ),
      drawer: const AppDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  buildMonthSelector(),
                  buildSummary(totalIncome, totalExpense),
                  buildBudgetWarning(totalExpense),
                  const SizedBox(height: 10),
                  buildIncomeExpensePieChart(totalIncome, totalExpense),
                  const SizedBox(height: 10),
                  buildExpenseBarChart(),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TransactionHistoryScreen(initialMonth: currentMonth)),
                      ).then((_) => fetchTransactions());
                    },
                    icon: const Icon(Icons.list_alt, size: 24),
                    label: const Text('Xem chi tiết thu chi', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showTransactionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}