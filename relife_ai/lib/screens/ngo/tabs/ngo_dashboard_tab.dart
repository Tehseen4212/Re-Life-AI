import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';
import '../../../core/app_theme.dart';

class NGODashboardTab extends StatefulWidget {
  const NGODashboardTab({super.key});

  @override
  State<NGODashboardTab> createState() => _NGODashboardTabState();
}

class _NGODashboardTabState extends State<NGODashboardTab> {
  final DatabaseService _dbService = DatabaseService();

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 32, color: AppTheme.textMainColor)),
            const SizedBox(height: 4),
            Text(title, style: GoogleFonts.inter(color: AppTheme.hintColor, fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ngoId = context.read<AuthProvider>().user?.id;
    final userProfile = context.read<AuthProvider>().profile;
    
    if (ngoId == null) return const Center(child: Text('Not Logged In'));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dbService.streamPendingDonations(),
        builder: (context, pendingSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _dbService.streamDonationHistory(ngoId),
            builder: (context, historySnap) {
              final pendingCount = pendingSnap.data?.length ?? 0;
              final historyData = historySnap.data ?? [];
              final activeItems = historyData.where((d) => d['status'] == 'claimed' || d['status'] == 'completed').toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome,', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFC4B5FD))),
                          Text(userProfile?.storeName ?? 'Hero', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                            child: Row(
                              children: [
                                const Icon(Icons.blur_on, color: AppTheme.successColor, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Relife Network Active', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                      Text('Searching for nearby food rescues...', style: GoogleFonts.inter(color: const Color(0xFFC4B5FD), fontSize: 11)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LIVE IMPACT METRICS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 1.0)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard('PENDING NEARBY', '$pendingCount', Icons.location_on_outlined, AppTheme.warningColor),
                              const SizedBox(width: 12),
                              _buildStatCard('TOTAL CLAIMS', '${activeItems.length}', Icons.handshake_outlined, AppTheme.primaryColor),
                            ],
                          ),
                          const SizedBox(height: 40),
                          
                          Text('RECENT ACTIVITY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 1.0)),
                          const SizedBox(height: 12),
                          
                          if (activeItems.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text('No recent activity.', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeItems.length > 5 ? 5 : activeItems.length,
                              itemBuilder: (context, index) {
                                final item = activeItems[index];
                                final reqType = item['request_type'] == 'offer' ? 'OFFER' : 'DONATION';
                                final status = item['status'];
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: status == 'completed' ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.primaryColor.withValues(alpha: 0.1), 
                                        shape: BoxShape.circle
                                      ),
                                      child: Icon(status == 'completed' ? Icons.done_all : Icons.handshake, color: status == 'completed' ? AppTheme.successColor : AppTheme.primaryColor, size: 20)
                                    ),
                                    title: Text("[$reqType] ${item['product']['name']}", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textMainColor)),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(status == 'completed' ? 'Handover Completed' : 'Claimed (Awaiting Store)', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
                                    ),
                                    trailing: const Icon(Icons.chevron_right, size: 20, color: AppTheme.hintColor),
                                  ),
                                );
                              },
                            )
                        ],
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
