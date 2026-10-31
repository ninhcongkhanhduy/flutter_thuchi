import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cai_dat_chung.dart';
import 'menu_dieu_huong.dart';

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