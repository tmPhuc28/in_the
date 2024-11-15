import 'dart:async';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:bluetooth_print/bluetooth_print.dart';
import '../enums/connection_state.dart';
import '../models/printer_device.dart';
import 'package:flutter/foundation.dart';

class BluetoothService {
  final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  final _stateController = StreamController<bool>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _deviceController = StreamController<List<PrinterDevice>>.broadcast();
  final _connectionStateController = StreamController<PrinterConnectionState>.broadcast();
  final _scannedDevices = <String, PrinterDevice>{};
  bool _isScanning = true;
  StreamSubscription? _bluetoothStateSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _scanSubscription;

  BluetoothService() {
    _initListeners();
  }

  Stream<bool> get stateStream => _stateController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<PrinterConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<PrinterDevice>> get deviceStream => _deviceController.stream;
  bool get isScanning => _isScanning;

  void _initListeners() {
    _bluetoothStateSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
      final isEnabled = state == fbp.BluetoothAdapterState.on;
      _stateController.add(isEnabled);

      // Nếu bluetooth bị tắt, reset các state khác
      if (!isEnabled) {
        _connectionStateController.add(PrinterConnectionState.idle);
        _deviceController.add([]);
        _scannedDevices.clear();
      }
    });

    _connectionStateSubscription = _bluetoothPrint.state.listen((state) {
      switch (state) {
        case BluetoothPrint.CONNECTED:
          _connectionStateController.add(PrinterConnectionState.connected);
          break;
        case BluetoothPrint.DISCONNECTED:
          _connectionStateController.add(PrinterConnectionState.idle);
          break;
        default:
        // Có thể thêm các trạng thái khác nếu cần
          break;
      }
    });
  }

  Future<bool> isEnabled() async {
    try {
      final isOn = await _bluetoothPrint.isOn;
      if (!isOn) {
        _connectionStateController.add(PrinterConnectionState.idle);
      }
      return isOn;
    } catch (e) {
      debugPrint('Error checking bluetooth state: $e');
      return false;
    }
  }

  Future<void> enable() async {
    try {
      await fbp.FlutterBluePlus.turnOn().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Không thể bật Bluetooth'),
      );

      // Đợi một chút để đảm bảo Bluetooth đã sẵn sàng
      await Future.delayed(const Duration(milliseconds: 500));

      final isEnabledBle = await isEnabled();
      if (!isEnabledBle) {
        throw Exception('Không thể bật Bluetooth');
      }
    } catch (e) {
      debugPrint('Error enabling bluetooth: $e');
      rethrow;
    }
  }

  Future<bool> verifyDeviceExists(String deviceId) async {
    try {
      if (!await isEnabled()) {
        return false;
      }

      final devices = await scanDevices(
        scanDuration: const Duration(milliseconds: 500),
        waitForResult: const Duration(milliseconds: 500),
      );
      return devices.any((device) => device.id == deviceId);
    } catch (e) {
      debugPrint('Error verifying device existence: $e');
      return false;
    }
  }

  void _emitDevices() {
    final devices = _scannedDevices.values.toList();
    _deviceController.add(List.unmodifiable(devices));
  }

  Future<List<PrinterDevice>> scanDevices({Duration scanDuration = const Duration(seconds: 4), Duration waitForResult = const Duration(milliseconds: 500),}) async {
    if (_isScanning) {
      await stopScan();
    }

    try {
      if (!await isEnabled()) {
        throw Exception('Bluetooth chưa được bật');
      }

      _isScanning = true;
      _scannedDevices.clear();
      _emitDevices();

      final completer = Completer<List<PrinterDevice>>();
      Timer? timeoutTimer;

      _scanSubscription = _bluetoothPrint.scanResults.listen(
            (results) {
          for (var device in results) {
            if (device.address != null) {
              final printerDevice = PrinterDevice(
                id: device.address!,
                name: device.name ?? 'Unknown Printer',
                address: device.address!,
                connectionState: PrinterConnectionState.idle,
              );

              if (!_scannedDevices.containsKey(printerDevice.id)) {
                _scannedDevices[printerDevice.id] = printerDevice;
                _emitDevices();
              }
            }
          }
        },
        onError: (error) {
          debugPrint('Scan error: $error');
          timeoutTimer?.cancel();
          _scanSubscription?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
          _isScanning = false;
          _emitDevices();
        },
        onDone: () {
          debugPrint('Scan completed');
        },
      );

      // Setup timeout
      timeoutTimer = Timer(scanDuration + waitForResult, () {
        stopScan();
        if (!completer.isCompleted) {
          completer.complete(_scannedDevices.values.toList());
        }
      });

      await _bluetoothPrint.startScan(timeout: scanDuration);
      return completer.future;

    } catch (e) {
      debugPrint('Error scanning devices: $e');
      _isScanning = false;
      _emitDevices();
      rethrow;
    }
  }

  Future<void> stopScan() async {
    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await _bluetoothPrint.stopScan();
    } finally {
      _isScanning = false;
      _emitDevices();
    }
  }

  Future<void> connect(PrinterDevice printer, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      _connectionStateController.add(PrinterConnectionState.connecting);

      final btDevice = BluetoothDevice();
      btDevice.name = printer.name;
      btDevice.address = printer.id;

      final isConnected = await _bluetoothPrint.connect(btDevice)
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('Kết nối quá thời gian cho phép');
      });

      if (isConnected != true) {
        _connectionStateController.add(PrinterConnectionState.idle);
        throw Exception('Không thể kết nối với máy in');
      }

      // Verify connection after successful connect
      await Future.delayed(const Duration(milliseconds: 500));
      final verified = await verifyConnection();
      if (!verified) {
        _connectionStateController.add(PrinterConnectionState.idle);
        throw Exception('Kết nối không ổn định');
      }

      _connectionStateController.add(PrinterConnectionState.connected);
      debugPrint('Successfully connected to ${printer.name}');
    } catch (e) {
      _connectionStateController.add(PrinterConnectionState.idle);
      debugPrint('Error in connect: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      _connectionStateController.add(PrinterConnectionState.disconnecting);
      await _bluetoothPrint.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
      _connectionStateController.add(PrinterConnectionState.idle);
    } catch (e) {
      _connectionStateController.add(PrinterConnectionState.idle);
      if (kDebugMode) {
        debugPrint('Error disconnecting printer: $e');
      }
      rethrow;
    }
  }

  Future<bool> verifyConnection() async {
    try {
      final isConnected = await _bluetoothPrint.isConnected ?? false;
      if (!isConnected) {
        _connectionStateController.add(PrinterConnectionState.idle);
      }
      return isConnected;
    } catch (e) {
      debugPrint('Error verifying connection: $e');
      _connectionStateController.add(PrinterConnectionState.idle);
      return false;
    }
  }

  Future<void> print(Map<String, dynamic> config, List<LineText> data) async {
    try {
      // Verify connection trước khi in
      final isConnected = await verifyConnection();
      if (!isConnected) {
        _connectionStateController.add(PrinterConnectionState.idle);
        throw Exception('Mất kết nối với máy in');
      }

      debugPrint('Starting print job...');
      debugPrint('Config: $config');
      debugPrint('Data length: ${data.length}');

      bool? printResult = await _bluetoothPrint.printReceipt(config, data);

      if (printResult != true) {
        throw Exception('Không thể in. Vui lòng kiểm tra lại máy in');
      }

      // Đợi một chút để đảm bảo lệnh in được xử lý
      await Future.delayed(const Duration(seconds: 1));

      // Verify lại kết nối sau khi in
      final stillConnected = await verifyConnection();
      if (!stillConnected) {
        _connectionStateController.add(PrinterConnectionState.idle);
        throw Exception('Mất kết nối sau khi in');
      }

      debugPrint('Print job completed successfully');
    } catch (e) {
      debugPrint('Error during printing: $e');
      _connectionStateController.add(PrinterConnectionState.idle);
      rethrow;
    }
  }

  Future<void> cleanupConnection() async {
    try {
      await disconnect();
      _connectionStateController.add(PrinterConnectionState.idle);
      _scannedDevices.clear();
      _emitDevices();
    } catch (e) {
      debugPrint('Error during connection cleanup: $e');
    }
  }

  void dispose() {
    stopScan();
    cleanupConnection();
    _bluetoothStateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _deviceController.close();
    _stateController.close();
    _connectionController.close();
    _connectionStateController.close();
    _bluetoothPrint.disconnect();
  }
}