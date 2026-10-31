import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  runApp(const ThuChiApp());
}

int? currentUserId;
String currentUserName = 'Người dùng';
String currentUserEmail = '';
String currentUserPhoto = '';

const String apiUrl = 'https://duyitek.com/thuchi/api.php';

String formatCurrency(dynamic amount) {
  double val = double.parse(amount.toString());
  return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
}

class ThuChiApp extends StatelessWidget {
  const ThuChiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý Thu Chi',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthCheckScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId != null) {
      currentUserId = userId;
      currentUserName = prefs.getString('user_name') ?? 'Người dùng';
      currentUserEmail = prefs.getString('user_email') ?? '';
      currentUserPhoto = prefs.getString('user_photo') ?? '';
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final response = await http.post(
          Uri.parse('$apiUrl?action=login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'google_id': account.id,
            'email': account.email,
            'display_name': account.displayName ?? 'Người dùng',
            'photo_url': account.photoUrl ?? '',
          }),
        );

        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          
          currentUserId = int.parse(data['user_id'].toString());
          currentUserName = account.displayName ?? 'Người dùng';
          currentUserEmail = account.email;
          currentUserPhoto = account.photoUrl ?? '';

          await prefs.setInt('user_id', currentUserId!);
          await prefs.setString('user_name', currentUserName);
          await prefs.setString('user_email', currentUserEmail);
          await prefs.setString('user_photo', currentUserPhoto);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        } else {
          _showError(data['message'] ?? 'Lỗi đăng nhập hệ thống');
        }
      }
    } catch (error) {
      _showError('Không thể kết nối Google: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text('Quản Lý Thu Chi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              const Text('Quản lý tài chính cá nhân hiệu quả', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 50),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _handleSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập bằng Google', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    await GoogleSignIn().signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    currentUserId = null;
    
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (_) => const LoginScreen()), 
      (route) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            accountName: Text(currentUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(currentUserEmail),
            currentAccountPicture: CircleAvatar(
              backgroundImage: currentUserPhoto.isNotEmpty ? NetworkImage(currentUserPhoto) : null,
              child: currentUserPhoto.isEmpty ? const Icon(Icons.person, size: 40) : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Tổng quan'),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Chi tiết Thu Chi'),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Quản lý Danh mục'),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CategoryManagerScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Lịch sử Hoạt động'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

class AppLog {
  static Future<void> add(String actionText) async {
    if (currentUserId == null) return;
    try {
      await http.post(
        Uri.parse('$apiUrl?action=add_log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action_text': actionText, 'user_id': currentUserId}),
      );
    } catch (e) {
      debugPrint('Lỗi khi lưu lịch sử: $e');
    }
  }
}

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

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});
  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  List categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    if (currentUserId == null) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiUrl?action=get_categories&user_id=$currentUserId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            categories = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteCategory(int id, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa danh mục "$name"? Các giao dịch thuộc danh mục này sẽ tự động được chuyển về mục "Khác".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final response = await http.post(
        Uri.parse('$apiUrl?action=delete_category'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id, 'user_id': currentUserId}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        AppLog.add("Đã xóa danh mục: $name");
        fetchCategories();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Có lỗi xảy ra')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void showCategoryDialog([Map? cat]) {
    final nameController = TextEditingController(text: cat != null ? cat['name'] : '');
    String type = cat != null ? cat['type'] : 'EXPENSE';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cat == null ? 'Thêm Danh Mục' : 'Sửa Danh Mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên danh mục')),
            if (cat == null)
              DropdownButtonFormField<String>(
                value: type,
                items: const [DropdownMenuItem(value: 'EXPENSE', child: Text('Chi tiêu')), DropdownMenuItem(value: 'INCOME', child: Text('Thu nhập'))],
                onChanged: (val) => type = val!,
                decoration: const InputDecoration(labelText: 'Loại'),
              )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final action = cat == null ? 'add_category' : 'update_category';
              final payload = cat == null
                  ? {'name': nameController.text, 'type': type, 'user_id': currentUserId}
                  : {'id': cat['id'], 'name': nameController.text, 'user_id': currentUserId};

              final response = await http.post(
                Uri.parse('$apiUrl?action=$action'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(payload),
              );
              
              final data = json.decode(response.body);
              if(data['status'] == 'error') {
                 if (!context.mounted) return;
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
                 Navigator.pop(context);
                 return;
              }
              
              if (cat != null) {
                if (cat['name'] != nameController.text) {
                  AppLog.add("Sửa tên danh mục: '${cat['name']}' -> '${nameController.text}'");
                }
              } else {
                AppLog.add("Thêm danh mục mới: '${nameController.text}'");
              }
              
              fetchCategories();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Danh mục')),
      drawer: const AppDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final c = categories[index];
                final isDefaultCategory = c['name'] == 'Khác';

                return ListTile(
                  title: Text(c['name']),
                  subtitle: Text(c['type'] == 'INCOME' ? 'Thu nhập' : 'Chi tiêu', style: TextStyle(color: c['type'] == 'INCOME' ? Colors.green : Colors.red)),
                  trailing: isDefaultCategory
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => showCategoryDialog(c)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => deleteCategory(int.parse(c['id'].toString()), c['name'])),
                          ],
                        ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    if (currentUserId == null) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiUrl?action=get_logs&user_id=$currentUserId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            logs = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải lịch sử: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử Hoạt động')),
      drawer: const AppDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : logs.isEmpty
              ? const Center(child: Text('Chưa có hoạt động nào được ghi nhận.'))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.history, color: Colors.blueGrey),
                        title: Text(log['action_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(log['created_at'] ?? ''),
                      ),
                    );
                  },
                ),
    );
  }
}

class TransactionDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Map? transaction;
  const TransactionDialog({super.key, required this.onSaved, this.transaction});
  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  List categories = [];
  String? selectedCategoryId;
  String selectedType = 'EXPENSE';
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  late DateTime selectedDate;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      selectedType = widget.transaction!['type'];
      amountController.text = double.parse(widget.transaction!['amount'].toString()).toStringAsFixed(0);
      noteController.text = widget.transaction!['note'] ?? '';
      selectedDate = DateTime.parse(widget.transaction!['transaction_date'].toString());
    } else {
      selectedDate = DateTime.now();
    }
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    if (currentUserId == null) return;
    try {
      final response = await http.get(Uri.parse('$apiUrl?action=get_categories&user_id=$currentUserId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            categories = (data['data'] as List).where((c) => c['type'] == selectedType).toList();
            if (categories.isNotEmpty) {
              bool currentExists = selectedCategoryId != null && categories.any((c) => c['id'].toString() == selectedCategoryId);
              if (!currentExists) {
                if (widget.transaction != null && categories.any((c) => c['id'].toString() == widget.transaction!['category_id'].toString())) {
                  selectedCategoryId = widget.transaction!['category_id'].toString();
                } else {
                  var invoiceCat = categories.cast<Map?>().firstWhere(
                    (c) => c != null && c['name'] != null && (c['name'].toString().toLowerCase().contains('hóa đơn') || c['name'].toString().toLowerCase().contains('hoa don')),
                    orElse: () => null,
                  );
                  if (invoiceCat != null) {
                    selectedCategoryId = invoiceCat['id'].toString();
                  } else {
                    selectedCategoryId = categories.first['id'].toString();
                  }
                }
              }
            } else {
              selectedCategoryId = null;
            }
          });
        }
      }
    } catch (_) {}
  }

Future<void> _scanBill() async {
    setState(() => isScanning = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image == null) {
        setState(() => isScanning = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      double detectedAmount = 0.0;
      double backupAmount = 0.0;

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String text = line.text;
          String lowerText = text.toLowerCase();
          
          // Trích xuất các cụm số có dạng tiền tệ (vd: 150.000, 200,000 hoặc 50000)
          var matches = RegExp(r'\b\d{1,3}(?:[.,]\d{3})+\b|\b\d{4,9}\b').allMatches(text);
          
          for (var match in matches) {
            String numStr = match.group(0)!;
            
            // 1. Bỏ qua số điện thoại (bắt đầu bằng 0)
            if (numStr.startsWith('0')) continue;
            
            // 2. Bỏ qua các dòng chứa định dạng ngày tháng hoặc giờ phút
            if (RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}').hasMatch(text) || 
                RegExp(r'\d{1,2}:\d{2}').hasMatch(text)) {
              continue;
            }

            // Làm sạch ký tự phân cách
            String cleanNum = numStr.replaceAll('.', '').replaceAll(',', '');
            double? val = double.tryParse(cleanNum);
            
            if (val != null && val < 500000000) { // Giới hạn dưới 500 triệu tránh nhầm Barcode
              
              // Phương án dự phòng: Bắt số lớn nhất ở dòng có chứa các từ khóa tổng tiền
              if (lowerText.contains('tong') || lowerText.contains('total') || 
                  lowerText.contains('thanh toan') || lowerText.contains('vnd') || 
                  lowerText.contains('đ')) {
                 if (val > backupAmount) backupAmount = val;
              }
              
              // Phương án chính: Tiền Việt Nam thường kết thúc bằng 00 hoặc 000
              // Số lớn nhất thỏa mãn điều kiện này chính là Tổng tiền
              if (cleanNum.endsWith('00')) {
                if (val > detectedAmount) {
                  detectedAmount = val;
                }
              }
            }
          }
        }
      }

      // Nếu không tìm thấy số chẵn nào hợp lý, dùng số backup tìm được
      if (detectedAmount == 0.0) {
        detectedAmount = backupAmount;
      }

      await textRecognizer.close();

      setState(() {
        selectedType = 'EXPENSE';
        if (detectedAmount > 0) {
          amountController.text = detectedAmount.toStringAsFixed(0);
        }
        noteController.text = "Thanh toán hóa đơn (Quét AI)";
        isScanning = false;
      });

      await fetchCategories();
      
      var invoiceCategory = categories.cast().firstWhere(
        (c) => c != null && 
               c['name'] != null && 
               (c['name'].toString().toLowerCase().contains('hóa đơn') || 
                c['name'].toString().toLowerCase().contains('hoa don')),
        orElse: () => null,
      );
      if (invoiceCategory != null) {
        setState(() {
          selectedCategoryId = invoiceCategory['id'].toString();
        });
      }

      if (detectedAmount == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể nhận diện số tiền. Vui lòng nhập thủ công!')),
        );
      }
    } catch (e) {
      setState(() => isScanning = false);
      debugPrint('Lỗi quét bill: $e');
    }
  }

  Future<void> _selectTransactionDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> submit() async {
    if (selectedCategoryId == null || amountController.text.isEmpty) return;

    final isEdit = widget.transaction != null;
    final action = isEdit ? 'update_transaction' : 'add_transaction';
    final newAmount = double.parse(amountController.text);
    final newNote = noteController.text;
    final newDateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    final payload = {
      'category_id': int.parse(selectedCategoryId!),
      'amount': newAmount,
      'type': selectedType,
      'note': newNote,
      'transaction_date': newDateStr,
      'user_id': currentUserId
    };

    if (isEdit) payload['id'] = widget.transaction!['id'];

    try {
      final response = await http.post(
        Uri.parse('$apiUrl?action=$action'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        String logMessage = '';

        if (isEdit) {
          List<String> changes = [];
          final oldAmount = double.parse(widget.transaction!['amount'].toString());
          if (oldAmount != newAmount) changes.add("Tiền: ${formatCurrency(oldAmount)} -> ${formatCurrency(newAmount)}");

          final oldCategoryId = widget.transaction!['category_id'].toString();
          if (oldCategoryId != selectedCategoryId) {
            String oldCatName = widget.transaction!['category_name'] ?? 'Cũ';
            String newCatName = categories.cast<Map?>().firstWhere((c) => c?['id'].toString() == selectedCategoryId, orElse: () => {'name': 'Mới'})?['name'] ?? 'Mới';
            changes.add("Mục: $oldCatName -> $newCatName");
          }

          final oldType = widget.transaction!['type'];
          if (oldType != selectedType) {
            changes.add("Loại: ${oldType == 'INCOME' ? 'Thu' : 'Chi'} -> ${selectedType == 'INCOME' ? 'Thu' : 'Chi'}");
          }

          final oldNote = widget.transaction!['note'] ?? '';
          if (oldNote != newNote) changes.add("Ghi chú: '$oldNote' -> '$newNote'");
          
          final oldDate = widget.transaction!['transaction_date'].toString();
          if (oldDate != newDateStr) changes.add("Ngày: $oldDate -> $newDateStr");

          String currentCatName = categories.cast<Map?>().firstWhere((c) => c?['id'].toString() == selectedCategoryId, orElse: () => {'name': 'Không rõ'})?['name'] ?? 'Không rõ';
          if (changes.isNotEmpty) {
            logMessage = "Sửa GD ngày $newDateStr (Mục '$currentCatName'): ${changes.join(", ")}";
          } else {
            logMessage = "Sửa GD ngày $newDateStr (Mục '$currentCatName'): Không có thay đổi";
          }
        } else {
          String catName = categories.cast<Map?>().firstWhere((c) => c?['id'].toString() == selectedCategoryId, orElse: () => {'name': ''})?['name'] ?? '';
          logMessage = "Thêm mới GD ngày $newDateStr: ${formatCurrency(newAmount)} đ vào mục '$catName' (Quét Bill)";
        }

        AppLog.add(logMessage);
        widget.onSaved();
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void showAddCategoryDialog() {
    showDialog(context: context, builder: (context) => AddCategoryDialog(type: selectedType, onAdded: fetchCategories));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.transaction == null ? 'Thêm giao dịch' : 'Sửa giao dịch'),
          if (widget.transaction == null)
            ElevatedButton.icon(
              onPressed: isScanning ? null : _scanBill,
              icon: isScanning 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt, size: 16),
              label: Text(isScanning ? 'Đang đọc...' : 'Quét Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedType,
              items: const [DropdownMenuItem(value: 'EXPENSE', child: Text('Chi tiêu')), DropdownMenuItem(value: 'INCOME', child: Text('Thu nhập'))],
              onChanged: (val) {
                if (val != null) {
                  setState(() { selectedType = val; selectedCategoryId = null; categories = []; });
                  fetchCategories();
                }
              },
              decoration: const InputDecoration(labelText: 'Loại giao dịch'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    items: categories.map((c) => DropdownMenuItem<String>(value: c['id'].toString(), child: Text(c['name']))).toList(),
                    onChanged: (val) => setState(() => selectedCategoryId = val),
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: showAddCategoryDialog)
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền')),
            const SizedBox(height: 10),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Ghi chú (Tùy chọn)')),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _selectTransactionDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Ngày giao dịch'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text("${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"), const Icon(Icons.calendar_today, size: 20)],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: submit, child: const Text('Lưu')),
      ],
    );
  }
}

class AddCategoryDialog extends StatefulWidget {
  final String type;
  final VoidCallback onAdded;
  const AddCategoryDialog({super.key, required this.type, required this.onAdded});
  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final nameController = TextEditingController();

  Future<void> submit() async {
    if (nameController.text.trim().isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('$apiUrl?action=add_category'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': nameController.text.trim(), 'type': widget.type, 'user_id': currentUserId}),
      );
      if (response.statusCode == 200) {
        AppLog.add("Thêm mới danh mục: '${nameController.text}'");
        widget.onAdded();
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Thêm danh mục ${widget.type == 'INCOME' ? 'Thu nhập' : 'Chi tiêu'}'),
      content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên danh mục mới'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: submit, child: const Text('Thêm')),
      ],
    );
  }
}
