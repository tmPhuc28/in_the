import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_device.dart';

final _printerUpdateController = StreamController<void>.broadcast();
Stream<void> get onPrinterUpdate => _printerUpdateController.stream;

class StorageService {
  static const String _lastPrinterIdKey = 'last_printer_id';
  static const String _printersKey = 'printers';

  Future<void> saveLastPrinter(PrinterDevice printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPrinterIdKey, printer.id);

    // Save printer details
    final printers = await getPrinters();
    printers[printer.id] = printer;
    await _savePrinters(printers);
  }

  Future<String?> getLastPrinterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastPrinterIdKey);
  }

  Future<PrinterDevice?> getPrinterDetails(String printerId) async {
    final printers = await getPrinters();
    return printers[printerId];
  }

  Future<Map<String, PrinterDevice>> getPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_printersKey);
    if (data == null) return {};

    final Map<String, dynamic> jsonData = jsonDecode(data);
    return jsonData.map((key, value) => MapEntry(
      key,
      PrinterDevice.fromJson(value),
    ));
  }

  Future<List<PrinterDevice>> getPrintersList() async {
    final printers = await getPrinters();
    final list = printers.values.toList();
    // Sắp xếp theo thời gian kết nối gần nhất
    list.sort((a, b) {
      if (a.lastConnectedTime == null) return 1;
      if (b.lastConnectedTime == null) return -1;
      return b.lastConnectedTime!.compareTo(a.lastConnectedTime!);
    });
    return list;
  }

  Future<void> deletePrinter(String printerId) async {
    final prefs = await SharedPreferences.getInstance();
    final printers = await getPrinters();

    // Xóa khỏi danh sách thiết bị
    printers.remove(printerId);
    await _savePrinters(printers);

    // Nếu là thiết bị được lưu cuối cùng, xóa luôn
    final lastPrinterId = await getLastPrinterId();
    if (lastPrinterId == printerId) {
      await prefs.remove(_lastPrinterIdKey);

      // Tìm thiết bị được kết nối gần nhất để set làm last printer
      final remainingPrinters = await getPrintersList();
      if (remainingPrinters.isNotEmpty) {
        await prefs.setString(_lastPrinterIdKey, remainingPrinters.first.id);
      }
    }

    _printerUpdateController.add(null); // Thông báo có thay đổi
  }

  Future<void> renamePrinter(String printerId, String newName) async {
    final printers = await getPrinters();
    if (printers.containsKey(printerId)) {
      final updatedPrinter = printers[printerId]!.copyWith(
        name: newName,
      );
      printers[printerId] = updatedPrinter;
      await _savePrinters(printers);
      _printerUpdateController.add(null); // Thông báo có thay đổi
    }
  }

  Future<void> _savePrinters(Map<String, PrinterDevice> printers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(
      printers.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_printersKey, jsonData);
    _printerUpdateController.add(null); // Thông báo có thay đổi
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void dispose() {
    _printerUpdateController.close();
  }
}