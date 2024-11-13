class PrinterDevice {
  final String id;
  final String name;
  final String address;
  final bool isConnected;
  final DateTime? lastConnectedTime;

  PrinterDevice({
    required this.id,
    required this.name,
    required this.address,
    this.isConnected = false,
    this.lastConnectedTime,
  });

  factory PrinterDevice.fromJson(Map<String, dynamic> json) {
    return PrinterDevice(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      isConnected: json['isConnected'] ?? false,
      lastConnectedTime: json['lastConnectedTime'] != null
          ? DateTime.parse(json['lastConnectedTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'isConnected': isConnected,
      'lastConnectedTime': lastConnectedTime?.toIso8601String(),
    };
  }

  PrinterDevice copyWith({
    String? id,
    String? name,
    String? address,
    bool? isConnected,
    DateTime? lastConnectedTime,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isConnected: isConnected ?? this.isConnected,
      lastConnectedTime: lastConnectedTime ?? this.lastConnectedTime,
    );
  }
}