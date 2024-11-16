import 'package:flutter/material.dart';
import '../../controllers/bluetooth_controller.dart';
import '../../di/service_locator.dart';
import '../../models/printer_device.dart';
import '../../services/storage_service.dart';
import '../widgets/custom_snackbar.dart';

class PrinterHistoryScreen extends StatefulWidget {
  const PrinterHistoryScreen({super.key});

  @override
  State<PrinterHistoryScreen> createState() => _PrinterHistoryScreenState();
}

class _PrinterHistoryScreenState extends State<PrinterHistoryScreen> {
  final _storageService = getIt<StorageService>();
  final _bluetoothController = getIt<BluetoothController>();
  List<PrinterDevice> _printerHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrinterHistory();
  }

  Future<void> _loadPrinterHistory() async {
    try {
      setState(() => _isLoading = true);
      final printers = await _storageService.getPrintersList();
      setState(() {
        _printerHistory = printers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Không thể tải lịch sử: $e',
        );
      }
    }
  }

  Future<void> _deletePrinter(PrinterDevice printer) async {
    try {
      await _storageService.deletePrinter(printer.id);
      await _bluetoothController.refreshPrinterInfo();
      if (mounted) {
        CustomSnackbar.showSuccess(
          context,
          'Đã xóa ${printer.name}',
        );
      }
      _loadPrinterHistory();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Không thể xóa thiết bị: $e',
        );
      }
    }
  }

  Future<void> _renamePrinter(PrinterDevice printer, String newName) async {
    try {
      await _storageService.renamePrinter(printer.id, newName);
      await _bluetoothController.refreshPrinterInfo();

      if (mounted) {
        CustomSnackbar.showSuccess(
          context,
          'Đã đổi tên thành công',
        );
      }
      _loadPrinterHistory();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Không thể đổi tên thiết bị: $e',
        );
      }
    }
  }

  Future<void> _showRenameDialog(PrinterDevice printer) async {
    final TextEditingController nameController = TextEditingController(text: printer.name);
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên thiết bị'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên thiết bị',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên thiết bị';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context);
                await _renamePrinter(printer, nameController.text.trim());
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(PrinterDevice printer) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa ${printer.name} khỏi lịch sử?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePrinter(printer);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử kết nối'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _printerHistory.isEmpty
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
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _printerHistory.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final printer = _printerHistory[index];
          return Dismissible(
            key: Key(printer.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
              ),
            ),
            confirmDismiss: (direction) async {
              await _showDeleteConfirmation(printer);
              return false; // Luôn trả về false để tự xử lý việc xóa
            },
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: printer.isConnected
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.print,
                  color: printer.isConnected
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
              title: Text(
                printer.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: printer.isConnected
                      ? Colors.green
                      : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Địa chỉ: ${printer.address}'),
                  Text(
                    'Lần kết nối cuối: ${_formatLastConnected(printer.lastConnectedTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Đổi tên'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20),
                        SizedBox(width: 8),
                        Text('Xóa'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'rename') {
                    await _showRenameDialog(printer);
                  } else if (value == 'delete') {
                    await _showDeleteConfirmation(printer);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}