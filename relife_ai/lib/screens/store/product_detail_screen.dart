import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/sensor_log.dart';
import '../../services/database_service.dart';
import '../../services/ai_assistant_service.dart';
import '../../utils/risk_calculator.dart';
import '../../core/app_theme.dart';
import 'local_analysis_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isAutoDonating = false;

  Widget _buildSensorGraph(List<SensorLog> logs, String title, Color color, double Function(SensorLog) extractor, {String unit = ''}) {
    if (logs.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Text('No historical data for $title', style: const TextStyle(color: Colors.grey)),
      );
    }

    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), extractor(e.value));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMainColor)),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.only(right: 16, top: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  )
                ),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => color.withValues(alpha: 0.8),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final log = logs[spot.x.toInt()];
                      final timeStr = DateFormat('HH:mm').format(log.recordedAt);
                      return LineTooltipItem(
                        '$timeStr\n${spot.y.toStringAsFixed(1)}$unit',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: color,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true, 
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.01)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Product Details', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900)),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<Product?>(
        stream: _dbService.streamProduct(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          if (!snapshot.hasData || snapshot.data == null) return const Center(child: Text('Product not found'));

          final product = snapshot.data!;
          
          Color riskColor = AppTheme.successColor;
          if (product.riskScore != null) {
            if (product.riskScore! > 0.7) {
              riskColor = AppTheme.errorColor;
            } else if (product.riskScore! > 0.4) riskColor = AppTheme.warningColor;
          }

          return StreamBuilder<List<SensorLog>>(
            stream: _dbService.streamProductSensorLogs(product.id),
            builder: (context, logSnapshot) {
              final logs = logSnapshot.data ?? [];
              final latestLog = logs.isNotEmpty ? logs.last : null;
              final latestPhoto = (latestLog?.photoUrls != null && latestLog!.photoUrls!.isNotEmpty) ? latestLog.photoUrls!.last : null;
              final customFreshness = latestLog?.freshnessScore;
              final lifePercentage = RiskCalculator.calculateProductLifePercentage(product, latestHardwareFreshness: customFreshness, latestHardwarePhotoUrl: latestPhoto);

              if (lifePercentage <= 25.0 && product.status != 'donated' && product.status != 'sold' && product.status != 'offered' && !_isAutoDonating) {
                _isAutoDonating = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await _dbService.createDonation(product.id, product.storeOwnerId);
                    if (context.mounted) {
                       String msg = '⚠️ Auto-Routed to NGO: ';
                       if (product.remainingShelfLife <= 1) {
                          msg += 'Expires in 24h. Immediate rescue required!';
                       } else if (lifePercentage < 15.0) {
                          msg += 'Critical condition (${lifePercentage.toStringAsFixed(0)}% life). Relocating to prevent total spoilage.';
                       } else {
                          msg += 'Freshness dropping (${lifePercentage.toStringAsFixed(0)}%). Please handover within ${product.remainingShelfLife} days.';
                       }
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800, duration: const Duration(seconds: 4)));
                    }
                  } finally {
                    if (mounted) {
                      setState(() { _isAutoDonating = false; });
                    }
                  }
                });
              }

              final currentRisk = RiskCalculator.calculateRisk(product, latestHardwareFreshness: customFreshness, latestHardwarePhotoUrl: latestPhoto);
              final riskClassification = RiskCalculator.getRiskClassification(currentRisk);
              final riskExplanation = RiskCalculator.getRiskExplanation(
                product: product,
                classification: riskClassification,
                customFreshness: customFreshness,
                latestPhotoUrl: latestPhoto,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overview Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(product.name, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textMainColor))),
                        if (latestPhoto != null)
                           Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(8)), child: const Text('ML Vision Active', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 10))),
                      ]
                    ),
                    Text('${product.category} • ${product.quantity} items', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 16)),
                    if (product.mfgDate != null || product.expiryDate != null) ...[
                      const SizedBox(height: 8),
                      Text('Mfg: ${product.mfgDate != null ? DateFormat('MMM dd, yyyy').format(product.mfgDate!) : 'N/A'}  |  Exp: ${product.expiryDate != null ? DateFormat('MMM dd, yyyy').format(product.expiryDate!) : 'N/A'}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                    ],
                    const SizedBox(height: 24),
                    
                    if (latestPhoto != null) ...[
                      Text('Live ML Hardware Snapshot', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMainColor)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(latestPhoto, height: 200, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Live Sensor Data
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBadge(Icons.thermostat, '${product.temperature}°C', Colors.redAccent),
                        _buildBadge(Icons.water_drop, '${product.humidity}%', Colors.blue),
                        _buildBadge(Icons.eco, '${((customFreshness ?? product.freshnessScore ?? 1.0) * 100).toStringAsFixed(0)}% Fresh', Colors.green),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Risk Analysis
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: riskColor),
                              const SizedBox(width: 8),
                              Text('Risk Analysis: $riskClassification', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: riskColor)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(riskExplanation, style: GoogleFonts.inter(color: AppTheme.textMainColor, height: 1.4)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Remaining Shelf Life:', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 14)),
                              Text('${product.remainingShelfLife} days', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: riskColor, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // AI Doctor Insight
                    _AIProductInsightCard(
                      product: product, 
                      lifePercentage: lifePercentage, 
                      temp: latestLog?.temperature, 
                      humidity: latestLog?.humidity,
                      freshnessScore: customFreshness,
                      riskClassification: riskClassification,
                    ),
                    const SizedBox(height: 32),

                    // Graphs
                    _buildSensorGraph(logs, 'Freshness Trend', Colors.green, (l) => l.freshnessScore ?? 1.0, unit: '%'),
                    const SizedBox(height: 32),
                    _buildSensorGraph(logs, 'Temperature History', Colors.redAccent, (l) => l.temperature, unit: '°C'),
                    const SizedBox(height: 32),
                    _buildSensorGraph(logs, 'Humidity Levels', Colors.blue, (l) => l.humidity, unit: '%'),
                    
                    const SizedBox(height: 40),
                    
                    // Actions
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LocalAnalysisScreen(product: product))),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Run Manual AI Scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (product.status == 'active')
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _dbService.markProductSold(product.id);
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark as Sold'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successColor,
                          side: const BorderSide(color: AppTheme.successColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AIProductInsightCard extends StatefulWidget {
  final Product product;
  final double lifePercentage;
  final double? temp;
  final double? humidity;
  final double? freshnessScore;
  final String riskClassification;

  const _AIProductInsightCard({
    required this.product,
    required this.lifePercentage,
    this.temp,
    this.humidity,
    this.freshnessScore,
    required this.riskClassification,
  });

  @override
  State<_AIProductInsightCard> createState() => _AIProductInsightCardState();
}

class _AIProductInsightCardState extends State<_AIProductInsightCard> {
  final AIAssistantService _aiService = AIAssistantService();
  String? _insight;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchInsight();
  }

  Future<void> _fetchInsight() async {
    setState(() => _loading = true);
    final res = await _aiService.getProductHealthInsight(
      productName: widget.product.name,
      lifePercentage: widget.lifePercentage,
      temp: widget.temp,
      humidity: widget.humidity,
      freshnessScore: widget.freshnessScore,
      riskClassification: widget.riskClassification,
    );
    if (mounted) setState(() { _insight = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withValues(alpha: 0.05), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text('AI Health Insight', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
              const Spacer(),
              if (!_loading) IconButton(icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryColor), onPressed: _fetchInsight),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(backgroundColor: Colors.transparent, color: AppTheme.primaryColor)
          else
            Text(_insight ?? 'Analyzing product health...', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMainColor, height: 1.5, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
