import 'dart:async';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:bluetooth_print/bluetooth_print.dart';
import '../models/printer_device.dart';
import 'package:flutter/foundation.dart';

class BluetoothService {
  final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  final _stateController = StreamController<bool>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  StreamSubscription? _bluetoothStateSubscription;
  StreamSubscription? _connectionStateSubscription;

  BluetoothService() {
    _initListeners();
  }

  Stream<bool> get stateStream => _stateController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  void _initListeners() {
    // Listen for bluetooth state changes
    _bluetoothStateSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
      _stateController.add(state == fbp.BluetoothAdapterState.on);
    });

    // Listen for connection state changes
    _connectionStateSubscription = _bluetoothPrint.state.listen((state) {
      _connectionController.add(state == BluetoothPrint.CONNECTED);
    });
  }

  Future<bool> isEnabled() async {
    try {
      return await _bluetoothPrint.isOn;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking bluetooth state: $e');
      }
      return false;
    }
  }

  Future<void> enable() async {
    try {
      await fbp.FlutterBluePlus.turnOn();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error enabling bluetooth: $e');
      }
      rethrow;
    }
  }

  Future<bool> verifyDeviceExists(String deviceId) async {
    try {
      final devices = await scanDevices(
        scanDuration: const Duration(milliseconds: 200),
        waitForResult: const Duration(milliseconds: 200),
      );
      return devices.any((device) => device.id == deviceId);
    } catch (e) {
      debugPrint('Error verifying device existence: $e');
      return false;
    }
  }

  Future<List<PrinterDevice>> scanDevices({Duration scanDuration = const Duration(seconds: 4), Duration waitForResult = const Duration(milliseconds: 500),}) async {
    try {
      final devices = <PrinterDevice>[];
      final completer = Completer<List<PrinterDevice>>();
      StreamSubscription? subscription;

      // Xử lý timeout
      Timer? timeoutTimer;
      timeoutTimer = Timer(scanDuration + waitForResult, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          debugPrint('Scan timeout after ${scanDuration.inSeconds}s');
          completer.complete(devices);
        }
      });

      subscription = _bluetoothPrint.scanResults.listen(
            (results) {
          for (var device in results) {
            if (device.address != null) {
              final printerDevice = PrinterDevice(
                id: device.address!,
                name: device.name ?? 'Unknown Printer',
                address: device.address!,
              );

              // Chỉ thêm thiết bị nếu chưa có trong danh sách
              if (!devices.any((d) => d.id == printerDevice.id)) {
                devices.add(printerDevice);
              }
            }
          }
        },
        onError: (error) {
          debugPrint('Scan error: $error');
          timeoutTimer?.cancel();
          subscription?.cancel();
          completer.completeError(error);
        },
      );

      debugPrint('Starting scan for ${scanDuration.inSeconds}s');
      await _bluetoothPrint.startScan(timeout: scanDuration);

      // Đợi thêm một khoảng thời gian để nhận kết quả cuối cùng
      await Future.delayed(waitForResult);
      timeoutTimer.cancel();
      await subscription.cancel();

      if (!completer.isCompleted) {
        completer.complete(devices);
      }

      return completer.future;
    } catch (e) {
      debugPrint('Error scanning devices: $e');
      rethrow;
    }
  }

  Future<void> connect(PrinterDevice printer) async {
    try {
      debugPrint('Attempting to connect to printer: ${printer.name}');

      // Đảm bảo không có kết nối nào đang active
      await disconnect();

      final btDevice = BluetoothDevice();
      btDevice.name = printer.name;
      btDevice.address = printer.id;

      final isConnected = await _bluetoothPrint.connect(btDevice);

      if (isConnected != true) {
        throw Exception('Không thể kết nối với máy in');
      }

      // Verify connection after successful connect
      await Future.delayed(const Duration(milliseconds: 500));
      final verified = await verifyConnection();
      if (!verified) {
        throw Exception('Kết nối không ổn định');
      }

      debugPrint('Successfully connected to ${printer.name}');
    } catch (e) {
      debugPrint('Error in connect: $e');
      // Ensure disconnected state on error
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _bluetoothPrint.disconnect();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error disconnecting printer: $e');
      }
      rethrow;
    }
  }

  Future<bool> verifyConnection() async {
    return await _bluetoothPrint.isConnected ?? false;
  }

  Future<void> print(Map<String, dynamic> config, List<LineText> data) async {
    try {
      // Kiểm tra kết nối trước khi in
      final isConnected = await _bluetoothPrint.isConnected ?? false;
      if (!isConnected) {
        throw Exception('Mất kết nối với máy in');
      }

      debugPrint('Starting print job...');
      debugPrint('Config: $config');
      debugPrint('Data length: ${data.length}');

      // Gửi lệnh in
      bool? printResult = await _bluetoothPrint.printReceipt(config, data);

      if (printResult != true) {
        throw Exception('Không thể in. Vui lòng kiểm tra lại máy in');
      }

      // Đợi một chút để đảm bảo lệnh in được xử lý
      await Future.delayed(const Duration(seconds: 1));

      debugPrint('Print job completed successfully');
    } catch (e) {
      debugPrint('Error during printing: $e');
      rethrow;
    }
  }

  void dispose() {
    _bluetoothStateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _stateController.close();
    _connectionController.close();
    _bluetoothPrint.disconnect();
  }
}