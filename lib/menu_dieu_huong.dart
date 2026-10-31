import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'cai_dat_chung.dart';
import 'man_hinh_dang_nhap.dart';
import 'man_hinh_tong_quan.dart';
import 'man_hinh_chi_tiet.dart';
import 'man_hinh_danh_muc.dart';
import 'man_hinh_lich_su.dart';

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