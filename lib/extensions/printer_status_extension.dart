import 'package:flutter/material.dart';
import '../enums/connection_state.dart';

extension PrinterStatusX on PrinterConnectionState {
  // Background color cho container
  Color get backgroundColor {
    switch (this) {
      case PrinterConnectionState.disabled:
      case PrinterConnectionState.idle:
        return Colors.grey.shade50;
      case PrinterConnectionState.connecting:
        return Colors.blue.shade50;
      case PrinterConnectionState.connected:
        return Colors.green.shade50;
      default: return Colors.grey.shade50;
    }
  }

  // Border color
  Color get borderColor {
    switch (this) {
      case PrinterConnectionState.disabled:
      case PrinterConnectionState.idle:
        return Colors.grey.shade300;
      case PrinterConnectionState.connecting:
        return Colors.blue.shade200;
      case PrinterConnectionState.connected:
        return Colors.green.shade200;
      default: return Colors.grey.shade300;
    }
  }

  // Text/Icon color
  Color get foregroundColor {
    switch (this) {
      case PrinterConnectionState.disabled:
      case PrinterConnectionState.idle:
        return Colors.grey.shade600;
      case PrinterConnectionState.connecting:
        return Colors.blue.shade600;
      case PrinterConnectionState.connected:
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // Status text - simplified
  String getStatusText(String? printerName) {
    switch (this) {
      case PrinterConnectionState.disabled:
        return 'Bluetooth chưa bật';
      case PrinterConnectionState.idle:
        return 'Chọn máy in';
      case PrinterConnectionState.connecting:
        return 'Đang kết nối...';
      case PrinterConnectionState.connected:
        return printerName ?? 'Đã kết nối';
      default:
        return 'Chọn máy in';
    }
  }

  // Show spinner only for connecting state
  bool get showSpinner => this == PrinterConnectionState.connecting;
}