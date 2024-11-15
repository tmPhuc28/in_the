import '../enums/connection_state.dart';

class PrinterDevice {
  final String id;
  final String name;
  final String address;
  final bool isConnected;
  final DateTime? lastConnectedTime;
  final PrinterConnectionState connectionState;

  const PrinterDevice({
    required this.id,
    required this.name,
    required this.address,
    this.isConnected = false,
    this.lastConnectedTime,
    this.connectionState = PrinterConnectionState.idle,
  });

  factory PrinterDevice.fromJson(Map<String, dynamic> json) {
    return PrinterDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      isConnected: json['isConnected'] as bool? ?? false,
      lastConnectedTime: json['lastConnectedTime'] != null
          ? DateTime.parse(json['lastConnectedTime'] as String)
          : null,
      connectionState: PrinterConnectionState.idle,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'isConnected': isConnected,
    'lastConnectedTime': lastConnectedTime?.toIso8601String(),
  };

  PrinterDevice copyWith({
    String? id,
    String? name,
    String? address,
    bool? isConnected,
    DateTime? lastConnectedTime,
    PrinterConnectionState? connectionState,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isConnected: isConnected ?? this.isConnected,
      lastConnectedTime: lastConnectedTime ?? this.lastConnectedTime,
      connectionState: connectionState ?? this.connectionState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PrinterDevice &&
              id == other.id &&
              name == other.name &&
              address == other.address &&
              isConnected == other.isConnected &&
              lastConnectedTime == other.lastConnectedTime &&
              connectionState == other.connectionState;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      address.hashCode ^
      isConnected.hashCode ^
      lastConnectedTime.hashCode ^
      connectionState.hashCode;
}