import 'dart:async';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/foundation.dart';
import '../services/app_lifecycle_service.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../models/printer_device.dart';

class BluetoothController extends ChangeNotifier {
  final BluetoothService _bluetoothService;
  final StorageService _storageService;
  final AppLifecycleService _lifecycleService;

  PrinterDevice? _connectedPrinter;
  PrinterDevice? _lastKnownPrinter;
  bool _isBluetoothEnabled = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  bool _isScanning = false;
  bool _isConnected = false;
  final List<PrinterDevice> _availableDevices = [];

  StreamSubscription? _deviceSubscription;

  BluetoothController({
    required BluetoothService bluetoothService,
    required StorageService storageService,
    required AppLifecycleService lifecycleService,
  })  : _bluetoothService = bluetoothService,
        _storageService = storageService,
        _lifecycleService = lifecycleService {
    _init();
    _initLifecycleHandlers();
  }


  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get isConnecting => _isConnecting;
  bool get isDisconnecting => _isDisconnecting;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  List<PrinterDevice> get availableDevices => List.unmodifiable(_availableDevices);
  PrinterDevice? get connectedPrinter => _connectedPrinter;
  PrinterDevice? get lastKnownPrinter => _lastKnownPrinter;
  AppLifecycleService get lifecycleService => _lifecycleService;


  void _initLifecycleHandlers() {
    _lifecycleService.onPause = () async {
      debugPrint('📱 App paused - Xử lý tạm dừng');

      try {
        await stopScan();
        // Lưu thông tin máy in trước khi ngắt kết nối

        if (_connectedPrinter != null) {
          debugPrint('💾 Lưu thông tin máy in: ${_connectedPrinter!.name}');
          final updatedPrinter = _connectedPrinter?.copyWith(
            lastConnectedTime: DateTime.now(),
          );
          await _storageService.saveLastPrinter(updatedPrinter!);
          _lastKnownPrinter =  updatedPrinter;
        }

        // Ngắt kết nối tạm thời
        await disconnectPrinter(temporary: true);
      } catch (e) {
        debugPrint('⚠️ Lỗi xử lý pause: $e');
      }
    };

    _lifecycleService.onResume = () async {
      debugPrint('📱 App resumed - Khôi phục trạng thái');

      // 1. Kiểm tra trạng thái bluetooth
      _isBluetoothEnabled = await _bluetoothService.isEnabled();
      notifyListeners();
      debugPrint('🔷 Bluetooth state: ${_isBluetoothEnabled ? "ON" : "OFF"}');

      // 2. Xử lý khôi phục kết nối nếu cần
      if (_lifecycleService.isPreviewOpen && _isBluetoothEnabled) {
        debugPrint('🔄 Preview đang mở và có kết nối trước đó');
        if (_lastKnownPrinter != null) {
          await reconnectLastPrinter();
        } else {
          debugPrint('⚠️ Không có thông tin máy in để kết nối lại');
        }
      }
    };

    _lifecycleService.onDetach = () async {
      debugPrint('📱 App detached - Dọn dẹp tài nguyên');
      await disconnectPrinter(temporary: false);
    };

    _lifecycleService.onInactive = () async {
      debugPrint('📱 App inactive - Lưu trạng thái');
      if (_connectedPrinter != null) {
        final updatedPrinter = _connectedPrinter?.copyWith(
          lastConnectedTime: DateTime.now(),
        );
        await _storageService.saveLastPrinter(updatedPrinter!);
      }
    };
  }

  Future<void> _init() async {
    // Load last known printer
    final savedPrinterId = await _storageService.getLastPrinterId();
    if (savedPrinterId != null) {
      _lastKnownPrinter = await _storageService.getPrinterDetails(savedPrinterId);
      debugPrint('📱 Xem có thiết bị đã kết nối trước đó chưa ${savedPrinterId ?? " : Không có"}');
    }

    // Initialize bluetooth listeners
    _bluetoothService.stateStream.listen((enabled) {
      _isBluetoothEnabled = enabled;
      if (!enabled) {
        _isConnected = false;
        _connectedPrinter = null;
      }
      notifyListeners();
    });

    _bluetoothService.connectionStream.listen((connected) {
      _isConnected = connected;
      if (!connected) {
        _connectedPrinter = null;
      }
      notifyListeners();
    });

    // Check initial bluetooth state
    _isBluetoothEnabled = await _bluetoothService.isEnabled();
    notifyListeners();

    _deviceSubscription = _bluetoothService.deviceStream.listen((devices) {
      _updateDeviceList(devices);
      notifyListeners();
    });
  }

  // Cập nhật device list với trạng thái kết nối
  void _updateDeviceList(List<PrinterDevice> devices) {
    _availableDevices.clear();

    final updatedDevices = devices.map((device) {
      return device.copyWith(
        isConnected: device.id == _connectedPrinter?.id,
        lastConnectedTime: device.id == _lastKnownPrinter?.id
            ? _lastKnownPrinter?.lastConnectedTime
            : null,
      );
    }).toList();

    // Sort devices (giữ nguyên logic sort cũ)
    updatedDevices.sort((a, b) {
      if (a.id == _connectedPrinter?.id) return -1;
      if (b.id == _connectedPrinter?.id) return 1;

      final aLastConnected = a.lastConnectedTime;
      final bLastConnected = b.lastConnectedTime;

      if (aLastConnected != null && bLastConnected != null) {
        return bLastConnected.compareTo(aLastConnected);
      }
      if (aLastConnected != null) return -1;
      if (bLastConnected != null) return 1;

      return a.name.compareTo(b.name);
    });

    _availableDevices.addAll(updatedDevices);
  }

  Future<void> enableBluetooth() async {
    try {
      await _bluetoothService.enable();
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling bluetooth: $e');
      }
      rethrow;
    }
  }

  Future<void> scanForDevices({Duration timeout = const Duration(seconds: 10)}) async {
    if (!_isBluetoothEnabled) {
      debugPrint('⚠️ Bluetooth not enabled');
      return;
    }

    try {
      _isScanning = true;
      notifyListeners();

      // Xóa danh sách thiết bị cũ trước khi scan mới
      _availableDevices.clear();
      notifyListeners();

      if (!_lifecycleService.isPreviewOpen) {
        debugPrint('Preview closed, stopping scan');
        await stopScan();
        return;
      }

      await _bluetoothService.scanDevices(
        scanDuration: timeout,
        waitForResult: const Duration(milliseconds: 500),
      );

    } catch (e) {
      debugPrint('Error scanning: $e');
      rethrow;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await _bluetoothService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connectToPrinter(PrinterDevice printer) async {
    // Nếu đang trong quá trình connect hoặc disconnect thì bỏ qua
    if (_isConnecting || _isDisconnecting) return;

    try {
      // Nếu đang kết nối với thiết bị này, thực hiện ngắt kết nối
      if (_isConnected && _connectedPrinter?.id == printer.id) {
        debugPrint('Disconnecting from printer: ${printer.name}');
        await disconnectPrinter(temporary: false);
        return;
      }

      _isConnecting = true;
      notifyListeners();

      // Ngắt kết nối với thiết bị khác nếu đang kết nối
      if (_isConnected && _connectedPrinter != null) {
        await disconnectPrinter(temporary: true);
      }

      debugPrint('Connecting to printer: ${printer.name}');
      await _bluetoothService.connect(printer);

      final updatedPrinter = printer.copyWith(
        isConnected: true,
        lastConnectedTime: DateTime.now(),
      );

      _connectedPrinter = printer;
      _lastKnownPrinter = _connectedPrinter;
      _isConnected = true;
      await _storageService.saveLastPrinter(updatedPrinter);

    } catch (e) {
      debugPrint('Error connecting: $e');
      _isConnected = false;
      _connectedPrinter = null;
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnectPrinter({bool temporary = false}) async {
    if (!_isConnected && _connectedPrinter == null) {
      debugPrint('ℹ️ Không có kết nối nào để ngắt');
      return;
    }

    try {
      final printerName = _connectedPrinter?.name ?? 'Unknown';
      debugPrint('🔄 Đang ngắt kết nối với $printerName...');
      _isDisconnecting = true;  // Set trạng thái đang ngắt kết nối
      notifyListeners();

      // Lưu thông tin máy in trước khi ngắt nếu cần
      if (!temporary && _connectedPrinter != null) {
        final updatedPrinter = _connectedPrinter?.copyWith(
          lastConnectedTime: DateTime.now(),
        );
        await _storageService.saveLastPrinter(updatedPrinter!);
        debugPrint('💾 Đã lưu thông tin máy in trước khi ngắt');
      }

      // Thực hiện ngắt kết nối
      await _bluetoothService.disconnect();

      // Đợi để đảm bảo ngắt kết nối hoàn tất
      await Future.delayed(const Duration(milliseconds: 300));

      _isConnected = false;
      if (!temporary) {
        _connectedPrinter = null;
        debugPrint('🗑️ Đã xóa thông tin máy in');
      }

      debugPrint('✅ Đã ngắt kết nối ${temporary ? "(tạm thời)" : ""}');
    } catch (e) {
      debugPrint('❌ Lỗi ngắt kết nối: $e');
      // Reset trạng thái ngay cả khi có lỗi
      _isConnected = false;
      if (!temporary) {
        _connectedPrinter = null;
      }
      rethrow;
    } finally {
      _isDisconnecting = false;  // Reset trạng thái
      notifyListeners();
    }
  }

  Future<void> reconnectLastPrinter() async {
    if (!_isBluetoothEnabled) {
      debugPrint('Bluetooth is not enabled, cannot reconnect');
      return;
    }

    try {
      bool isActuallyConnected = await verifyPrinterConnection();
      if (isActuallyConnected) return;

      if (_lastKnownPrinter != null && !_isConnected) {
        final exists = await verifyLastPrinterExists();
        if (!exists) throw Exception('Không tìm thấy máy in đã lưu');

        await connectToPrinter(_lastKnownPrinter!);
      }
    } catch (e) {
      _isConnected = false;
      _connectedPrinter = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> printData(Map<String, dynamic> config, List<LineText> data) async {
    if (!_isConnected || _connectedPrinter == null) {
      throw Exception('Chưa kết nối máy in');
    }

    try {
      // Verify connection before printing
      final isStillConnected = await _bluetoothService.verifyConnection();
      if (!isStillConnected) {
        _isConnected = false;
        notifyListeners();
        throw Exception('Mất kết nối với máy in');
      }

      debugPrint('Printing data to ${_connectedPrinter?.name}');
      await _bluetoothService.print(config, data);
    } catch (e) {
      debugPrint('Error printing: $e');
      // Reset connection state if printing fails
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> verifyPrinterConnection() async {
    if (!_isConnected || _connectedPrinter == null) return false;
    return await _bluetoothService.verifyConnection();
  }

  Future<bool> verifyLastPrinterExists() async {
    if (_lastKnownPrinter == null) return false;
    return await _bluetoothService.verifyDeviceExists(_lastKnownPrinter!.id);
  }

  @override
  void dispose() {
    stopScan();
    _lifecycleService.dispose();
    _bluetoothService.dispose();
    _deviceSubscription?.cancel();
    super.dispose();
  }
}