import 'package:flutter/material.dart';
import 'man_hinh_dang_nhap.dart';

void main() {
  runApp(const ThuChiApp());
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