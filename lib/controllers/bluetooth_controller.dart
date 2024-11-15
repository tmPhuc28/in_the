import 'dart:async';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/foundation.dart';
import '../enums/connection_state.dart';
import '../services/app_lifecycle_service.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../models/printer_device.dart';

class BluetoothController extends ChangeNotifier {
  // Dependencies
  final BluetoothService _bluetoothService;
  final StorageService _storageService;
  final AppLifecycleService _lifecycleService;

  PrinterDevice? _connectedPrinter;
  PrinterDevice? _lastKnownPrinter;
  String? _processingDeviceId;
  PrinterConnectionState _connectionState = PrinterConnectionState.idle;
  bool _isBluetoothEnabled = false;
  bool _isScanning = false;
  bool _isConnected = false;
  final List<PrinterDevice> _availableDevices = [];

  // Subscriptions & Timers
  StreamSubscription? _deviceSubscription;
  StreamSubscription? _connectionStateSubscription;
  Completer<void>? _connectionLock;
  Timer? _connectionTimeout;

  // Public getters
  PrinterConnectionState get connectionState => _connectionState;
  String? get processingDeviceId => _processingDeviceId;
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  List<PrinterDevice> get availableDevices => List.unmodifiable(_availableDevices);
  PrinterDevice? get connectedPrinter => _connectedPrinter;
  PrinterDevice? get lastKnownPrinter => _lastKnownPrinter;
  AppLifecycleService get lifecycleService => _lifecycleService;

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

  // Core state checks
  bool isDeviceConnected(String deviceId) {
    return _connectedPrinter?.id == deviceId &&
        _connectionState == PrinterConnectionState.connected;
  }

  PrinterConnectionState getPrinterStatus() {
    if (!isBluetoothEnabled) {
      return PrinterConnectionState.disabled;
    }

    if (isDeviceConnected(connectedPrinter?.id ?? '')) {
      return PrinterConnectionState.connected;
    }

    if (connectionState == PrinterConnectionState.connecting) {
      return PrinterConnectionState.connecting;
    }

    if (connectionState == PrinterConnectionState.disconnecting) {
      return PrinterConnectionState.disconnecting;
    }

    return PrinterConnectionState.idle;
  }

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
        _connectionState = PrinterConnectionState.idle;
        _isConnected = false;
        _connectedPrinter = null;
      }
      notifyListeners();
    });

    // Subscribe to connection state changes
    _connectionStateSubscription = _bluetoothService.connectionStateStream.listen((state) {
      _connectionState = state;
      _isConnected = state == PrinterConnectionState.connected;
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

  Future<void> enableBluetooth() async {
    if (_connectionState != PrinterConnectionState.idle) {
      debugPrint('Cannot enable Bluetooth while in busy state');
      return;
    }

    try {
      await _bluetoothService.enable();
    } catch (e) {
      debugPrint('Error enabling bluetooth: $e');
      rethrow;
    }
  }

  Future<void> scanForDevices({Duration timeout = const Duration(seconds: 10)}) async {
    if (!_isBluetoothEnabled) {
      debugPrint('⚠️ Bluetooth not enabled');
      return;
    }

    if (_connectionState != PrinterConnectionState.idle) {
      debugPrint('⚠️ Cannot scan while connecting/disconnecting');
      return;
    }

    try {
      _isScanning = true;
      notifyListeners();

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
    if (_connectionLock != null) {
      debugPrint('⚠️ Đang có quá trình kết nối/ngắt kết nối, bỏ qua yêu cầu mới');
      return;
    }

    _connectionLock = Completer<void>();
    _processingDeviceId = printer.id;

    try {
      _connectionTimeout = Timer(const Duration(seconds: 10), () {
        if (!_connectionLock!.isCompleted) {
          _connectionLock!.completeError('Quá thời gian kết nối');
        }
      });

      // Toggle disconnect if clicking connected device
      if (_isConnected && _connectedPrinter?.id == printer.id) {
        await disconnectPrinter(temporary: false);
        return;
      }

      // Disconnect from current device if exists
      if (_isConnected && _connectedPrinter != null) {
        await disconnectPrinter(temporary: true);
      }

      await Future.delayed(const Duration(seconds: 1));
      await _bluetoothService.connect(printer);

      final updatedPrinter = printer.copyWith(
        isConnected: true,
        lastConnectedTime: DateTime.now(),
      );

      _connectedPrinter = updatedPrinter;
      _lastKnownPrinter = updatedPrinter;
      _isConnected = true;

      await _storageService.saveLastPrinter(updatedPrinter);

    } catch (e) {
      debugPrint('Error connecting: $e');
      _isConnected = false;
      _connectedPrinter = null;
      rethrow;
    } finally {
      _connectionTimeout?.cancel();
      if (_connectionLock != null && !_connectionLock!.isCompleted) {
        _connectionLock!.complete();
      }
      _connectionLock = null;
      _processingDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> disconnectPrinter({bool temporary = false}) async {
    if (!_isConnected && _connectedPrinter == null) {
      debugPrint('ℹ️ Không có kết nối nào để ngắt');
      return;
    }

    if (_connectionState == PrinterConnectionState.disconnecting) {
      debugPrint('⚠️ Đang trong quá trình ngắt kết nối');
      return;
    }

    try {
      final printerName = _connectedPrinter?.name ?? 'Unknown';
      final printerId = _connectedPrinter?.id;

      _connectionState = PrinterConnectionState.disconnecting;
      _processingDeviceId = printerId;
      notifyListeners();

      debugPrint('🔄 Đang ngắt kết nối với $printerName...');

      if (!temporary && _connectedPrinter != null) {
        final updatedPrinter = _connectedPrinter?.copyWith(
          lastConnectedTime: DateTime.now(),
          connectionState: PrinterConnectionState.idle,
        );
        await _storageService.saveLastPrinter(updatedPrinter!);
      }

      await Future.delayed(const Duration(seconds: 1));
      await _bluetoothService.disconnect();

      _isConnected = false;
      if (!temporary) {
        _connectedPrinter = null;
      }

      _connectionState = PrinterConnectionState.idle;

    } catch (e) {
      debugPrint('❌ Lỗi ngắt kết nối: $e');
      _connectionState = PrinterConnectionState.idle;
      _isConnected = false;
      if (!temporary) {
        _connectedPrinter = null;
      }
      rethrow;
    } finally {
      _processingDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> reconnectLastPrinter() async {
    if (!_isBluetoothEnabled || _connectionState != PrinterConnectionState.idle) {
      debugPrint('Cannot reconnect: Bluetooth disabled or busy state');
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
      _connectionState = PrinterConnectionState.idle;
      _isConnected = false;
      _connectedPrinter = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> printData(Map<String, dynamic> config, List<LineText> data) async {
    if (_connectionState != PrinterConnectionState.connected ||
        _connectedPrinter == null) {
      throw Exception('Chưa kết nối máy in');
    }

    try {
      final isStillConnected = await _bluetoothService.verifyConnection();
      if (!isStillConnected) {
        _connectionState = PrinterConnectionState.idle;
        _isConnected = false;
        notifyListeners();
        throw Exception('Mất kết nối với máy in');
      }

      debugPrint('Printing data to ${_connectedPrinter?.name}');
      await _bluetoothService.print(config, data);
    } catch (e) {
      debugPrint('Error printing: $e');
      _connectionState = PrinterConnectionState.idle;
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> verifyPrinterConnection() async {
    if (_connectionState != PrinterConnectionState.connected ||
        _connectedPrinter == null) {
      return false;
    }
    return await _bluetoothService.verifyConnection();
  }

  Future<bool> verifyLastPrinterExists() async {
    if (_lastKnownPrinter == null) return false;
    return await _bluetoothService.verifyDeviceExists(_lastKnownPrinter!.id);
  }

  void _updateDeviceList(List<PrinterDevice> devices) {
    _availableDevices.clear();

    final updatedDevices = devices.map((device) {
      // Cập nhật trạng thái kết nối cho từng thiết bị
      if (device.id == _processingDeviceId) {
        return device.copyWith(
          connectionState: _connectionState,
          isConnected: _connectionState == PrinterConnectionState.connected,
          lastConnectedTime: _connectionState == PrinterConnectionState.connected ?
          DateTime.now() : device.lastConnectedTime,
        );
      } else if (device.id == _connectedPrinter?.id) {
        return device.copyWith(
          connectionState: PrinterConnectionState.connected,
          isConnected: true,
          lastConnectedTime: _connectedPrinter?.lastConnectedTime,
        );
      }

      return device.copyWith(
        connectionState: PrinterConnectionState.idle,
        isConnected: false,
        lastConnectedTime: device.id == _lastKnownPrinter?.id ?
        _lastKnownPrinter?.lastConnectedTime : null,
      );
    }).toList();

    // Sort devices with new logic
    updatedDevices.sort((a, b) {
      // Connected device first
      if (a.connectionState == PrinterConnectionState.connected) return -1;
      if (b.connectionState == PrinterConnectionState.connected) return 1;

      // Processing device second
      if (a.id == _processingDeviceId) return -1;
      if (b.id == _processingDeviceId) return 1;

      // Last connected devices next
      final aLastConnected = a.lastConnectedTime;
      final bLastConnected = b.lastConnectedTime;

      if (aLastConnected != null && bLastConnected != null) {
        return bLastConnected.compareTo(aLastConnected);
      }
      if (aLastConnected != null) return -1;
      if (bLastConnected != null) return 1;

      // Finally sort by name
      return a.name.compareTo(b.name);
    });

    _availableDevices.addAll(updatedDevices);
  }


  @override
  void dispose() {
    stopScan();
    _connectionTimeout?.cancel();
    _connectionStateSubscription?.cancel();
    _connectionLock = null;
    _lifecycleService.dispose();
    _bluetoothService.dispose();
    _deviceSubscription?.cancel();
    super.dispose();
  }
}