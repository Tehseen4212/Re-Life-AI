class Product {
  final String id;
  final String storeOwnerId;
  final String name;
  final String category;
  final int quantity;
  final DateTime entryDate;
  final int? shelfLifeDays;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final String? storageNo;
  final double? freshnessScore; 
  final double? riskScore; 
  final double temperature;
  final double humidity;
  final double envRisk;
  final String status;
  final String? barcode;
  final double price;

  Product({
    required this.id,
    required this.storeOwnerId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.entryDate,
    this.shelfLifeDays,
    this.mfgDate,
    this.expiryDate,
    this.storageNo,
    this.freshnessScore,
    this.riskScore,
    this.temperature = 0.0,
    this.humidity = 0.0,
    this.envRisk = 0.0,
    this.status = 'active',
    this.barcode,
    this.price = 0.0,
  });

  int get daysStored {
    final now = DateTime.now();
    return now.difference(entryDate).inDays;
  }

  int get remainingShelfLife {
    int baseRemaining = 0;
    if (expiryDate != null) {
      baseRemaining = expiryDate!.difference(DateTime.now()).inDays;
    } else if (shelfLifeDays != null) {
      baseRemaining = shelfLifeDays! - daysStored;
    }
    
    if (baseRemaining <= 0) return 0;
    
    // Dynamically throttle absolute calendar days based on AI physical state
    if (freshnessScore != null && freshnessScore! < 1.0) {
      int adjusted = (baseRemaining * freshnessScore!).round();
      return adjusted < 0 ? 0 : adjusted;
    }
    
    return baseRemaining;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      storeOwnerId: json['store_owner_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      quantity: json['quantity'] as int,
      entryDate: DateTime.parse(json['entry_date'] as String),
      shelfLifeDays: json['shelf_life_days'] as int?,
      mfgDate: json['mfg_date'] != null ? DateTime.parse(json['mfg_date'] as String) : null,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date'] as String) : null,
      storageNo: json['storage_no'] as String?,
      freshnessScore: json['freshness_score'] != null ? double.parse(json['freshness_score'].toString()) : null,
      riskScore: json['risk_score'] != null ? double.parse(json['risk_score'].toString()) : null,
      temperature: json['temperature'] != null ? double.parse(json['temperature'].toString()) : 0.0,
      humidity: json['humidity'] != null ? double.parse(json['humidity'].toString()) : 0.0,
      envRisk: json['env_risk'] != null ? double.parse(json['env_risk'].toString()) : 0.0,
      status: json['status'] as String? ?? 'active',
      barcode: json['barcode'] as String?,
      price: json['price'] != null ? double.parse(json['price'].toString()) : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'store_owner_id': storeOwnerId,
      'name': name,
      'category': category,
      'quantity': quantity,
      'entry_date': entryDate.toIso8601String(),
      if (shelfLifeDays != null) 'shelf_life_days': shelfLifeDays,
      if (mfgDate != null) 'mfg_date': mfgDate!.toIso8601String(),
      if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String(),
      if (storageNo != null) 'storage_no': storageNo,
      if (freshnessScore != null) 'freshness_score': freshnessScore,
      if (riskScore != null) 'risk_score': riskScore,
      'temperature': temperature,
      'humidity': humidity,
      'env_risk': envRisk,
      'status': status,
      if (barcode != null) 'barcode': barcode,
      'price': price,
    };
  }
}
