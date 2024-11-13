class CardInfo {
  final String provider;
  final String denomination;
  final String rechargeCode;
  final String serialNumber;

  CardInfo({
    required this.provider,
    required this.denomination,
    required this.rechargeCode,
    required this.serialNumber,
  });

  factory CardInfo.fromJson(Map<String, dynamic> json) {
    return CardInfo(
      provider: json['provider'],
      denomination: json['denomination'],
      rechargeCode: json['rechargeCode'],
      serialNumber: json['serialNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'denomination': denomination,
      'rechargeCode': rechargeCode,
      'serialNumber': serialNumber,
    };
  }

  CardInfo copyWith({
    String? provider,
    String? denomination,
    String? rechargeCode,
    String? serialNumber,
  }) {
    return CardInfo(
      provider: provider ?? this.provider,
      denomination: denomination ?? this.denomination,
      rechargeCode: rechargeCode ?? this.rechargeCode,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }
}