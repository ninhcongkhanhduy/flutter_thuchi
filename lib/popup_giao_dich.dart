import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'cai_dat_chung.dart';
import 'popup_them_danh_muc.dart';

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
          
          var matches = RegExp(r'\b\d{1,3}(?:[.,]\d{3})+\b|\b\d{4,9}\b').allMatches(text);
          
          for (var match in matches) {
            String numStr = match.group(0)!;
            
            if (numStr.startsWith('0')) continue;
            
            if (RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}').hasMatch(text) || 
                RegExp(r'\d{1,2}:\d{2}').hasMatch(text)) {
              continue;
            }

            String cleanNum = numStr.replaceAll('.', '').replaceAll(',', '');
            double? val = double.tryParse(cleanNum);
            
            if (val != null && val < 500000000) { 
              if (lowerText.contains('tong') || lowerText.contains('total') || 
                  lowerText.contains('thanh toan') || lowerText.contains('vnd') || 
                  lowerText.contains('đ')) {
                 if (val > backupAmount) backupAmount = val;
              }
              
              if (cleanNum.endsWith('00')) {
                if (val > detectedAmount) {
                  detectedAmount = val;
                }
              }
            }
          }
        }
      }

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
      
      var invoiceCategory = categories.cast<Map?>().firstWhere(
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