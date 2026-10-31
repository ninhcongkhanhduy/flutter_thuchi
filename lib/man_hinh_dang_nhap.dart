import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'cai_dat_chung.dart';
import 'man_hinh_tong_quan.dart';

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