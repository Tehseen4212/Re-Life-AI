import '../models/product.dart';

class RiskCalculator {
  /// Calculates the Product Life Percentage based on the new formula:
  /// Product Life % = (0.45 * F) + (0.35 * S) + (0.20 * (100 - E))
  static double calculateProductLifePercentage(Product product, {double? latestHardwareFreshness, String? latestHardwarePhotoUrl}) {
    // 1. Calculate S (Shelf Life Percentage)
    int remainingDays = product.remainingShelfLife;
    if (product.expiryDate != null) {
      remainingDays = product.expiryDate!.difference(DateTime.now()).inDays;
    }
    
    // Cap S between 0 to 100
    double sPercentage = 0;
    int totalLife = product.shelfLifeDays ?? 0;
    
    if (product.expiryDate != null && product.mfgDate != null) {
      totalLife = product.expiryDate!.difference(product.mfgDate!).inDays;
    }
    
    if (totalLife > 0) {
      sPercentage = (remainingDays / totalLife) * 100.0;
    }
    if (sPercentage < 0) sPercentage = 0;
    if (sPercentage > 100) sPercentage = 100;

    // 2. Calculate F (Freshness Score)
    // Freshness is derived from ML vision or defaults to 100%
    double rawFreshness = latestHardwareFreshness ?? product.freshnessScore ?? 1.0;
    double fPercentage = rawFreshness * 100.0;
    if (fPercentage < 0) fPercentage = 0;
    if (fPercentage > 100) fPercentage = 100;

    // 3. Calculate E (Environmental Risk)
    // Environmental risk starts at 0 (ideal) and scales up to 100 (high risk)
    double eScore = 0.0;
    
    // Add base environmental risk from the product model
    eScore += (product.envRisk * 100.0);
    
    // Add category-specific environmental penalties
    if (product.category == 'Dairy') {
      if (product.temperature > 6.0) eScore += 40;
      if (product.temperature > 10.0) eScore += 60; 
    } else if (product.category == 'Produce' || product.category == 'Vegetables') {
      if (product.temperature > 15.0) eScore += 30;
      if (product.humidity < 50.0) eScore += 20; 
      if (product.humidity > 90.0 && product.temperature > 20.0) eScore += 50; 
      if (latestHardwarePhotoUrl != null && rawFreshness < 0.5) eScore += 40; 
    } else if (product.category == 'Medicine') {
      if (product.temperature > 25.0) eScore += 60; 
      if (product.humidity > 65.0) eScore += 30;
    } else if (product.category == 'Meat') {
      if (product.temperature > -2.0) eScore += 50;
      if (product.temperature > 4.0) eScore += 50; 
    }

    if (eScore > 100) eScore = 100;
    if (eScore < 0) eScore = 0;

    // 4. Final Formula Computation (Non-Linear Strict Caps)
    // The base structural life cannot exceed the actual ML Freshness (Risk Score) 
    // or the physically remaining Expiry / Shelf life. Whichever is lower is the ceiling.
    double baseLife = fPercentage < sPercentage ? fPercentage : sPercentage;
    
    // An environmental penalty (Temp/Humidity) can drag down the score by up to 25%, 
    // but users can correct the fridge to recover this percentage.
    double finalLifePercentage = baseLife - (eScore * 0.25);
    
    if (finalLifePercentage < 0) finalLifePercentage = 0;
    if (finalLifePercentage > 100) finalLifePercentage = 100;
    
    return double.parse(finalLifePercentage.toStringAsFixed(1));
  }

  /// Existing Legacy risk map that converts the Product Life % inversely into Risk (0 to 1.0)
  /// This prevents crashing other components that rely on a 0.0 -> 1.0 risk metric.
  static double calculateRisk(Product product, {double? latestHardwareFreshness, String? latestHardwarePhotoUrl}) {
    double lifePercentage = calculateProductLifePercentage(
      product, 
      latestHardwareFreshness: latestHardwareFreshness,
      latestHardwarePhotoUrl: latestHardwarePhotoUrl
    );
    // Inverse standard: 100% life = 0.0 risk. 0% life = 1.0 risk.
    return double.parse(((100.0 - lifePercentage) / 100.0).toStringAsFixed(2));
  }

  static String getRiskClassification(double riskScore) {
    if (riskScore <= 0.4) {
      return 'Low Risk';
    } else if (riskScore <= 0.7) {
      return 'Medium Risk';
    } else {
      return 'High Risk';
    }
  }

  static String getRecommendation(String classification, int remainingDays) {
    if (remainingDays <= 2) {
      return 'Force Donate';
    }
    if (remainingDays <= 4) {
      return 'Apply Discount';
    }

    if (classification == 'Low Risk') {
      return 'Continue Selling';
    } else if (classification == 'Medium Risk') {
      return 'Apply Discount';
    } else {
      return 'Donate to NGO';
    }
  }

  static String getRiskExplanation({
    required Product product,
    required String classification,
    double? customFreshness,
    String? latestPhotoUrl,
  }) {
    int remainingDays = product.remainingShelfLife;
    if (product.expiryDate != null) {
      remainingDays = product.expiryDate!.difference(DateTime.now()).inDays;
    }

    if (remainingDays <= 0) return 'DANGER: Product is expired (Past physical/calculated expiry).';
    if (remainingDays <= 1) return 'URGENT: Product expires within 24 hours. Immediate donation or disposal mandated by safety protocols.';
    if (remainingDays <= 2) return 'Critical: Shelf life is almost over (≤ 2 days remaining). Force donation triggered.';
    if (remainingDays <= 4) return 'Warning: Product is near expiry (≤ 4 days). Discount advised.';

    // Explain IoT violations based on Category
    if (product.category == 'Dairy' && product.temperature > 6.0) return 'AI Alert: Dairy cold-chain compromise detected (Temp > 6°C). High spoil speed forecast.';
    if (product.category == 'Medicine' && product.temperature > 25.0) return 'AI Alert: Thermal violation for pharmaceuticals. Composition breakdown likely.';
    if (product.category == 'Meat' && product.temperature > -2.0) return 'AI Alert: Deep freeze temperature breach. Extreme bacterial growth chance.';
    if ((product.category == 'Produce' || product.category == 'Vegetables') && product.humidity < 50.0) return 'AI Alert: Low humidity detecting wilting cascade in produce.';

    double finalFreshness = customFreshness ?? product.freshnessScore ?? 1.0;
    if (latestPhotoUrl != null && finalFreshness < 0.5) {
      return 'Computer Vision ML matched severe visual signs of spoilage/bruising from live hardware camera feeds.';
    } else if (finalFreshness < 0.4) {
      return 'Sensor fusion analytics indicate high likelihood of hidden spoilage.';
    }

    if (product.category == 'Produce' || product.category == 'Vegetables') {
      return 'Product is stable. ML Photos and IoT hardware report normal visual limits.';
    } else if (product.category == 'Medicine') {
      return 'Product is stable. Storage temperature and moisture perfectly maintained within pharmaceutical bounds.';
    }

    return 'Product is currently stable and safely within category hardware boundaries.';
  }
}
