import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';
import '../analytics_summary_screen.dart';
import '../../../core/app_theme.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, {VoidCallback? onTap}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ]
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFEDE9FE), shape: BoxShape.circle),
                    child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                  ),
                  const Spacer(),
                  Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textMainColor)),
                  const SizedBox(height: 4),
                  Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.hintColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().user?.id;
    if (userId == null) return const Center(child: Text('Not Logged In'));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().streamDonationHistoryForStore(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          
          final history = snapshot.data ?? [];
          
          final completedItems = history.where((d) => d['status'] == 'completed').toList();
          
          int totalItemsSaved = 0;
          for (var item in completedItems) {
            final productData = item['product'] is List ? (item['product'] as List).first : item['product'];
            totalItemsSaved += ((productData?['quantity'] ?? 0) as int);
          }
          
          final wastePrevented = (totalItemsSaved * 0.5).toStringAsFixed(1);
          final completedDonationsCount = completedItems.where((d) => d['request_type'] == 'donation').length;
          final completedOffersCount = completedItems.where((d) => d['request_type'] == 'offer').length;

          // Compute impact score based on items
          final impactScore = totalItemsSaved * 10;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gradient Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('Analytics & Impact', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 32),
                      Text('TOTAL IMPACT SCORE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFC4B5FD), letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Text('$impactScore', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text('points earned', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFC4B5FD))),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REAL-TIME WASTE REDUCTION', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 0.8)),
                      const SizedBox(height: 12),
                      
                      SizedBox(
                        height: 320, // 2 rows of 160
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _buildStatCard(context, 'Items Handed Over', '$totalItemsSaved', Icons.check_circle_outline),
                                  _buildStatCard(context, 'Waste Prevented', '${wastePrevented}kg', Icons.eco_outlined),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  _buildStatCard(
                                    context, 
                                    'Free Donations', 
                                    '$completedDonationsCount', 
                                    Icons.handshake_outlined,
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsSummaryScreen(userId: userId, filterType: 'donation')))
                                  ),
                                  _buildStatCard(
                                    context, 
                                    'Discount Offers', 
                                    '$completedOffersCount', 
                                    Icons.local_offer_outlined,
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsSummaryScreen(userId: userId, filterType: 'offer')))
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      
                      // New Pipeline Tracker Card
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryColor.withValues(alpha: 0.05), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsSummaryScreen(userId: userId, filterType: 'all'))),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.analytics_rounded, color: AppTheme.primaryColor, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text('Impact Pipeline Tracker', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textMainColor)),
                                        const SizedBox(height: 2),
                                        Text('View pending, today, and historical logs', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryColor, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
