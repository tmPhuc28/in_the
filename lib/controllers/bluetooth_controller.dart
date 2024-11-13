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
  bool _isScanning = false;
  bool _isConnected = false;
  final List<PrinterDevice> _availableDevices = [];

  BluetoothController({
    required BluetoothService bluetoothService,
    required StorageService storageService,
    required AppLifecycleService lifecycleService,
  })  : _bluetoothService = bluetoothService,
        _storageService = storageService,
        _lifecycleService = lifecycleService {
    _init();
    _initLifecycleHandlers();
    scanForDevices();
  }


  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get isConnecting => _isConnecting;
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
        // Lưu thông tin máy in trước khi ngắt kết nối
        if (_connectedPrinter != null) {
          debugPrint('💾 Lưu thông tin máy in: ${_connectedPrinter!.name}');
          await _storageService.saveLastPrinter(_connectedPrinter!);
          _lastKnownPrinter =  _connectedPrinter;
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
        await _storageService.saveLastPrinter(_connectedPrinter!);
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

  Future<void> scanForDevices() async {
    if (!_isBluetoothEnabled || _isScanning) return;

    try {
      _isScanning = true;
      _availableDevices.clear();
      notifyListeners();

      final devices = await _bluetoothService.scanDevices();
      _availableDevices.addAll(devices);

      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> connectToPrinter(PrinterDevice printer, {Duration timeout = const Duration(seconds: 10),}) async {

    if (_isConnecting) {
      debugPrint('⚠️ Đang có yêu cầu kết nối khác, bỏ qua...');
      return;
    }

    try {
      _isConnecting = true;
      notifyListeners();
      debugPrint('🔄 Đang kết nối với ${printer.name}...');


      // Ngắt kết nối hiện tại nếu đang kết nối với máy in khác
      if (_isConnected && _connectedPrinter?.id != printer.id) {
        debugPrint('📱 Ngắt kết nối với máy in hiện tại trước khi kết nối mới');
        await disconnectPrinter(temporary: true);
      }

      // Thử kết nối với timeout
      bool connected = await Future.any([
        _bluetoothService.connect(printer).then((_) {
          debugPrint('✅ Kết nối thành công với ${printer.name}');
          return true;
        }),
        Future.delayed(timeout)
            .then((_) => throw TimeoutException('Kết nối quá thời gian chờ')),
      ]);

      if (connected) {
        final updatedPrinter = printer.copyWith(
          isConnected: true,
          lastConnectedTime: DateTime.now(),
        );
        _connectedPrinter = printer;
        _lastKnownPrinter = _connectedPrinter;
        _isConnected = true;
        await _storageService.saveLastPrinter(updatedPrinter);
        debugPrint('💾 Đã lưu thông tin máy in ${printer.name}');
      }
    } catch (e) {
      debugPrint('❌ Lỗi kết nối: $e');
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

      // Lưu thông tin máy in trước khi ngắt nếu cần
      if (!temporary && _connectedPrinter != null) {
        await _storageService.saveLastPrinter(_connectedPrinter!);
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
    _lifecycleService.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }
}