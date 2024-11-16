import '../enums/connection_state.dart';

class PrinterDevice {
  final String id;
  final String name;
  final String address;
  final DateTime? lastConnectedTime;
  final PrinterConnectionState connectionState;

  const PrinterDevice({
    required this.id,
    required this.name,
    required this.address,
    this.lastConnectedTime,
    this.connectionState = PrinterConnectionState.idle,
  });

  // Thay thế biến isConnected bằng getter
  bool get isConnected => connectionState == PrinterConnectionState.connected;

  // Cập nhật copyWith để không còn tham số isConnected
  PrinterDevice copyWith({
    String? id,
    String? name,
    String? address,
    DateTime? lastConnectedTime,
    PrinterConnectionState? connectionState,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lastConnectedTime: lastConnectedTime ?? this.lastConnectedTime,
      connectionState: connectionState ?? this.connectionState,
    );
  }

  // Cập nhật fromJson để sử dụng connectionState
  factory PrinterDevice.fromJson(Map<String, dynamic> json) {
    return PrinterDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      lastConnectedTime: json['lastConnectedTime'] != null
          ? DateTime.parse(json['lastConnectedTime'] as String)
          : null,
      connectionState: json['connectionState'] != null
          ? PrinterConnectionState.values[json['connectionState'] as int]
          : PrinterConnectionState.idle,
    );
  }

  // Cập nhật toJson để lưu connectionState
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'lastConnectedTime': lastConnectedTime?.toIso8601String(),
    'connectionState': connectionState.index,
  };
}