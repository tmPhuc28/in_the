import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../services/print_service.dart';
import '../models/card_info.dart';
import '../views/widgets/custom_snackbar.dart';
import 'bluetooth_controller.dart';
import 'dart:typed_data';

class PrintController extends ChangeNotifier {
  final PrintService _printService;
  final BluetoothController _bluetoothController;

  String _selectedProvider = 'Viettel';
  String _selectedDenomination = '20.000 VND';
  bool _printWithQR = false;
  CardInfo? _lastPrintedCard;

  // Cache cho preview image và card info
  Uint8List? _cachedPreviewImage;
  CardInfo? _cachedCardInfo;
  String? _cachedCardText;

  // Getter cho cached image
  Uint8List? get cachedPreviewImage => _cachedPreviewImage;

  final Map<String, List<String>> _providerDenominations = {
    'Viettel': [
      '20.000 VND',
      '30.000 VND',
      '50.000 VND',
      '100.000 VND',
      '200.000 VND',
      '300.000 VND',
      '500.000 VND',
      '1.000.000 VND'
    ],
    'Vinaphone': [
      '20.000 VND',
      '30.000 VND',
      '50.000 VND',
      '100.000 VND',
      '200.000 VND',
      '300.000 VND',
      '500.000 VND',
      '1.000.000 VND'
    ],
    'Mobifone': [
      '20.000 VND',
      '30.000 VND',
      '50.000 VND',
      '100.000 VND',
      '200.000 VND',
      '300.000 VND',
      '500.000 VND',
      '1.000.000 VND'
    ],
  };

  PrintController({
    required PrintService printService,
    required BluetoothController bluetoothController,
  })  : _printService = printService,
        _bluetoothController = bluetoothController;

  // Getters
  String get selectedProvider => _selectedProvider;

  String get selectedDenomination => _selectedDenomination;

  bool get printWithQR => _printWithQR;

  List<String> get availableProviders => _providerDenominations.keys.toList();

  List<String> get availableDenominations =>
      _providerDenominations[_selectedProvider] ?? [];

  CardInfo? get lastPrintedCard => _lastPrintedCard;

  void setProvider(String? provider) {
    if (provider != null && provider != _selectedProvider) {
      _selectedProvider = provider;
      _selectedDenomination = _providerDenominations[provider]!.first;
      _clearCache(); // Clear cache khi đổi provider
      notifyListeners();
    }
  }

  void setDenomination(String? denomination) {
    if (denomination != null && denomination != _selectedDenomination) {
      _selectedDenomination = denomination;
      _clearCache(); // Clear cache khi đổi mệnh giá
      notifyListeners();
    }
  }

  void toggleQR(bool value) {
    if (_printWithQR != value) {
      _printWithQR = value;
      _clearCache(); // Clear cache khi toggle QR
      notifyListeners();
    }
  }

  void _clearCache() {
    _cachedPreviewImage = null;
    _cachedCardInfo = null;
    _cachedCardText = null;
  }

  bool _shouldRegeneratePreview(String cardText) {
    return _cachedPreviewImage == null ||
        _cachedCardText != cardText ||
        _cachedCardInfo == null;
  }

  Future<CardInfo?> validateCardInput(
      BuildContext context, String input) async {
    try {
      if (input.trim().isEmpty) {
        CustomSnackbar.showWarning(
          context,
          'Vui lòng nhập mã thẻ và số serial',
        );
        return null;
      }

      // Extract card info from input
      final lines = input.split('\n');
      String rechargeCode = '';
      String serialNumber = '';

      for (var line in lines) {
        final lowerLine = line.toLowerCase().trim();
        if (lowerLine.contains('mã nạp:') ||
            lowerLine.contains('mã thẻ:') ||
            lowerLine.contains('ma nap:') ||
            lowerLine.contains('ma the:')) {
          rechargeCode = line.split(':').last.trim();
        } else if (lowerLine.contains('số seri:') ||
            lowerLine.contains('số serial:') ||
            lowerLine.contains('so seri:') ||
            lowerLine.contains('serial:') ||
            lowerLine.contains('seri:')) {
          serialNumber = line.split(':').last.trim();
        }
      }

      rechargeCode = rechargeCode.replaceAll(RegExp(r'[^0-9]'), '');
      serialNumber = serialNumber.replaceAll(RegExp(r'[^0-9]'), '');

      debugPrint('Extracted recharge code: $rechargeCode');
      debugPrint('Extracted serial: $serialNumber');

      // Validate thông tin đầy đủ
      if (rechargeCode.isEmpty && serialNumber.isEmpty) {
        CustomSnackbar.showWarning(
          context,
          'Vui lòng nhập đúng định dạng:\nMã nạp: xxxxxxx\nSerial: xxxxxxx',
        );
        return null;
      }

      if (rechargeCode.isEmpty) {
        CustomSnackbar.showError(
          context,
          'Chưa nhập mã nạp thẻ',
        );
        return null;
      }

      if (serialNumber.isEmpty) {
        CustomSnackbar.showError(
          context,
          'Chưa nhập số serial',
        );
        return null;
      }

      // Validate độ dài mã thẻ
      if (!_isValidCardNumber(rechargeCode, _selectedProvider)) {
        CustomSnackbar.showError(
          context,
          'Mã nạp không hợp lệ cho nhà mạng $_selectedProvider\n'
          'Viettel: 13 hoặc 15 số\n'
          'Vinaphone: 14 số\n'
          'Mobifone: 12 số',
        );
        return null;
      }

      final formattedRechargeCode =
          _formatCardNumber(rechargeCode, _selectedProvider);
      final formattedSerialNumber =
          _formatCardNumber(serialNumber, _selectedProvider);

      return CardInfo(
        provider: _selectedProvider,
        denomination: _selectedDenomination,
        rechargeCode: formattedRechargeCode,
        serialNumber: formattedSerialNumber,
      );
    } catch (e) {
      debugPrint('Error validating card input: $e');
      CustomSnackbar.showError(
        context,
        'Lỗi kiểm tra dữ liệu: $e',
      );
      return null;
    }
  }

  Future<Uint8List?> createPreview(
      BuildContext context, String cardText) async {
    try {
      if (_shouldRegeneratePreview(cardText)) {
        debugPrint('Generating new preview image...');

        // Validate và lấy thông tin thẻ
        final cardInfo = await validateCardInput(context, cardText);
        if (cardInfo == null) return null;

        final imageData = await _printService.createPreviewImage(
          cardInfo: cardInfo,
          withQR: _printWithQR,
        );

        _cachedPreviewImage = imageData;
        _cachedCardInfo = cardInfo;
        _cachedCardText = cardText;

        return imageData;
      } else {
        debugPrint('Using cached preview image');
        return _cachedPreviewImage;
      }
    } catch (e) {
      debugPrint('Error creating preview: $e');
      _clearCache();
      CustomSnackbar.showError(
        context,
        'Lỗi tạo preview: $e',
      );
      return null;
    }
  }

  Future<bool> printCard(BuildContext context, String cardText) async {
    if (!_bluetoothController.isConnected) {
      CustomSnackbar.showError(
        context,
        'Vui lòng kết nối máy in trước khi in',
      );
      return false;
    }

    try {
      debugPrint('Starting print process...');

      Uint8List? imageData;
      CardInfo? cardInfo;

      if (_shouldRegeneratePreview(cardText)) {
        debugPrint('Generating new print image...');
        cardInfo = await validateCardInput(context, cardText);
        if (cardInfo == null) return false;

        imageData = await _printService.createPreviewImage(
          cardInfo: cardInfo,
          withQR: _printWithQR,
        );

        _cachedPreviewImage = imageData;
        _cachedCardInfo = cardInfo;
        _cachedCardText = cardText;
      } else {
        debugPrint('Using cached image for printing');
        imageData = _cachedPreviewImage;
        cardInfo = _cachedCardInfo;
      }

      if (imageData == null || cardInfo == null) {
        CustomSnackbar.showError(
          context,
          'Không có dữ liệu để in',
        );
        return false;
      }

      if (!await _bluetoothController.verifyPrinterConnection()) {
        CustomSnackbar.showError(
          context,
          'Mất kết nối với máy in',
        );
        return false;
      }

      final config = {
        'width': 380,
        'height': 0,
        'gap': 2,
        'speed': 2,
        'drawer': false,
        'cut': true,
      };

      final printData = _printService.createPrintData(imageData);
      debugPrint('Print data prepared with ${printData.length} items');

      await Future.delayed(const Duration(seconds: 1));
      await _bluetoothController.printData(config, printData);

      await Future.delayed(const Duration(seconds: 1));
      if (!await _bluetoothController.verifyPrinterConnection()) {
        CustomSnackbar.showError(
          context,
          'In không thành công, vui lòng thử lại',
        );
        return false;
      }

      _lastPrintedCard = cardInfo;
      notifyListeners();

      CustomSnackbar.showSuccess(
        context,
        'In thành công',
      );

      debugPrint('Print completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error during print process: $e');
      CustomSnackbar.showError(
        context,
        'Lỗi trong quá trình in: $e',
      );
      return false;
    }
  }

  // Helper methods...
  bool _isValidCardNumber(String number, String provider) {
    number = number.replaceAll(RegExp(r'[^0-9]'), '');
    switch (provider.toLowerCase()) {
      case 'viettel':
        return number.length == 13 || number.length == 15;
      case 'vinaphone':
        return number.length == 14;
      case 'mobifone':
        return number.length == 12;
      default:
        return false;
    }
  }

  String _formatCardNumber(String number, String provider) {
    number = number.replaceAll(RegExp(r'[^0-9]'), '');
    switch (provider.toLowerCase()) {
      case 'viettel':
        if (number.length == 13) {
          return '${number.substring(0, 3)} ${number.substring(3, 7)} '
              '${number.substring(7, 11)} ${number.substring(11)}';
        }
        if (number.length == 15) {
          return '${number.substring(0, 4)} ${number.substring(4, 8)} '
              '${number.substring(8, 12)} ${number.substring(12)}';
        }
        break;

      case 'vinaphone':
        if (number.length == 14) {
          return '${number.substring(0, 4)} ${number.substring(4, 8)} '
              '${number.substring(8, 12)} ${number.substring(12)}';
        }
        break;

      case 'mobifone':
        if (number.length == 12) {
          return '${number.substring(0, 4)} ${number.substring(4, 8)} '
              '${number.substring(8)}';
        }
        break;
    }
    return number;
  }
}
