import 'package:flutter/material.dart';

import '../../di/service_locator.dart';
import '../../models/printer_device.dart';
import '../../services/storage_service.dart';

class PrinterHistoryScreen extends StatefulWidget {
  const PrinterHistoryScreen({super.key});

  @override
  State<PrinterHistoryScreen> createState() => _PrinterHistoryScreenState();
}

class _PrinterHistoryScreenState extends State<PrinterHistoryScreen> {
  final _storageService = getIt<StorageService>();
  List<PrinterDevice> _printerHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPrinterHistory();
  }

  Future<void> _loadPrinterHistory() async {
    final printers = await _storageService.getPrinters();
    setState(() {
      _printerHistory = printers as List<PrinterDevice>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Lịch sử kết nối máy in'),
      ),
      body: _printerHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.print_disabled_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có lịch sử kết nối máy in',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _printerHistory.length,
              itemBuilder: (context, index) {
                final printer = _printerHistory[index];
                return ListTile(
                  leading: Icon(
                    Icons.print,
                    color: printer.isConnected ? Colors.green : Colors.grey,
                  ),
                  title: Text(printer.name),
                  subtitle: Text(
                    'Địa chỉ: ${printer.address}\n'
                    'Lần kết nối cuối: ${_formatLastConnected(printer.lastConnectedTime)}',
                  ),
                  trailing: Text(
                    printer.isConnected ? 'Đã kết nối' : 'Chưa kết nối',
                    style: TextStyle(
                      color: printer.isConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatLastConnected(DateTime? lastConnected) {
    if (lastConnected == null) return 'Chưa từng kết nối';

    final now = DateTime.now();
    final difference = now.difference(lastConnected);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes phút trước';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours giờ trước';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return '$days ngày trước';
    } else {
      return '${lastConnected.day.toString().padLeft(2, '0')}/'
          '${lastConnected.month.toString().padLeft(2, '0')}/'
          '${lastConnected.year}';
    }
  }
}
