import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cai_dat_chung.dart';
import 'menu_dieu_huong.dart';

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