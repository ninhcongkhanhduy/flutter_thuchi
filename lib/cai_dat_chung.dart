import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      debugPrint('Lỗi khi lưu lịch sử : $e');
    }
  }
}