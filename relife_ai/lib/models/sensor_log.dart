class SensorLog {
  final String id;
  final String productId;
  final double temperature;
  final double humidity;
  final double envRisk;
  final double? freshnessScore;
  final List<String>? photoUrls;
  final DateTime recordedAt;

  SensorLog({
    required this.id,
    required this.productId,
    required this.temperature,
    required this.humidity,
    required this.envRisk,
    this.freshnessScore,
    this.photoUrls,
    required this.recordedAt,
  });

  factory SensorLog.fromJson(Map<String, dynamic> json) {
    return SensorLog(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      temperature: double.parse(json['temperature'].toString()),
      humidity: double.parse(json['humidity'].toString()),
      envRisk: double.parse(json['env_risk'].toString()),
      freshnessScore: json['freshness_score'] != null ? double.parse(json['freshness_score'].toString()) : null,
      photoUrls: json['photo_urls'] != null ? List<String>.from(json['photo_urls']) : null,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'product_id': productId,
      'temperature': temperature,
      'humidity': humidity,
      'env_risk': envRisk,
      'freshness_score': freshnessScore,
      'photo_urls': photoUrls,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
