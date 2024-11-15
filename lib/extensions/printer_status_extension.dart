import 'package:flutter/material.dart';
import '../enums/connection_state.dart';

extension PrinterStatusX on PrinterConnectionState {
  // Chỉ giữ lại các phương thức liên quan đến hiển thị trạng thái
  Color get backgroundColor {
    switch (this) {
      case PrinterConnectionState.disabled:
      case PrinterConnectionState.idle:
        return Colors.grey.shade50;
      case PrinterConnectionState.connecting:
        return Colors.blue.shade50;
      case PrinterConnectionState.connected:
        return Colors.green.shade50;
      case PrinterConnectionState.disconnecting:
        return Colors.red.shade50;
    }
  }

  Color get borderColor {
    switch (this) {
      case PrinterConnectionState.disabled:
      case PrinterConnectionState.idle:
        return Colors.grey.shade300;
      case PrinterConnectionState.connecting:
        return Colors.blue.shade200;
      case PrinterConnectionState.connected:
        return Colors.green.shade200;
      case PrinterConnectionState.disconnecting:
        return Colors.red.shade200;
    }
  }

  Color get foregroundColor {
    switch (this) {
      case PrinterConnectionState.disabled:
      case PrinterConnectionState.idle:
        return Colors.grey.shade600;
      case PrinterConnectionState.connecting:
        return Colors.blue.shade600;
      case PrinterConnectionState.connected:
        return Colors.green.shade600;
      case PrinterConnectionState.disconnecting:
        return Colors.red.shade600;
    }
  }

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
      case PrinterConnectionState.disconnecting:
        return 'Đang ngắt kết nối...';
    }
  }

  bool get showSpinner =>
      this == PrinterConnectionState.connecting ||
          this == PrinterConnectionState.disconnecting;
}