enum PrinterConnectionState {
  idle, // Chưa kết nối
  disabled, // Bluetooth bị tắt
  disconnecting, // Đang ngắt kết nối
  connecting, // Đang kết nối
  connected, // Đã kết nối
}