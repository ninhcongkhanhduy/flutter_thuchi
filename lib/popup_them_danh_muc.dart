import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cai_dat_chung.dart';

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