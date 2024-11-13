import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_device.dart';

class StorageService {
  static const String _lastPrinterIdKey = 'last_printer_id';
  static const String _printersKey = 'printers';

  Future<void> saveLastPrinter(PrinterDevice printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPrinterIdKey, printer.id);

    // Save printer details
    final printers = await _getPrinters();
    printers[printer.id] = printer;
    await _savePrinters(printers);
  }

  Future<String?> getLastPrinterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastPrinterIdKey);
  }

  Future<PrinterDevice?> getPrinterDetails(String printerId) async {
    final printers = await _getPrinters();
    return printers[printerId];
  }

  Future<Map<String, PrinterDevice>> _getPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_printersKey);
    if (data == null) return {};

    final Map<String, dynamic> jsonData = jsonDecode(data);
    return jsonData.map((key, value) => MapEntry(
      key,
      PrinterDevice.fromJson(value),
    ));
  }

  Future<void> _savePrinters(Map<String, PrinterDevice> printers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(
      printers.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_printersKey, jsonData);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}