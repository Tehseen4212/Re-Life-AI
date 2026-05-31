import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';
import '../../../models/product.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_theme.dart';

class NGORequestsTab extends StatefulWidget {
  const NGORequestsTab({super.key});

  @override
  State<NGORequestsTab> createState() => _NGORequestsTabState();
}

class _NGORequestsTabState extends State<NGORequestsTab> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final ngoId = context.read<AuthProvider>().user?.id;
    if (ngoId == null) return const Center(child: Text('Not Logged In'));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dbService.streamPendingDonations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          
          final items = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Text('Incoming Requests', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                    const SizedBox(height: 12),
                    Text('${items.length} items available in your area', style: GoogleFonts.inter(color: const Color(0xFFC4B5FD), fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              Expanded(
                child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.05), shape: BoxShape.circle),
                            child: const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text('No pending requests', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMainColor)),
                          const SizedBox(height: 8),
                          Text('We will notify you when stores donate.', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final rawItem = items[index];
                        
                        // Handle potential List or Map from Supabase Joins
                        final productData = rawItem['product'] is List 
                            ? (rawItem['product'] as List).first 
                            : rawItem['product'];
                        final storeData = rawItem['store'] is List 
                            ? (rawItem['store'] as List).first 
                            : rawItem['store'];

                        if (productData == null) return const SizedBox.shrink();

                        final Product product = Product.fromJson(productData);
                        final Map<String, dynamic>? store = storeData;
                        final donationId = rawItem['id'];

                        final storeName = store?['store_name'] as String? ?? 'Local Store';
                        final storeAddress = store?['location_address'] as String? ?? 'Unknown Location';
                        final mapUrl = store?['google_map_url'] as String? ?? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(storeAddress)}';

                        final requestType = rawItem['request_type'] == 'offer' ? 'OFFER' : 'DONATION';
                        final isOffer = requestType == 'OFFER';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(storeName, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.textMainColor))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: isOffer ? AppTheme.warningColor : AppTheme.successColor, borderRadius: BorderRadius.circular(99)),
                                      child: Text(requestType, style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Store Address + Map Launcher Row
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.location_on, size: 16, color: AppTheme.primaryColor)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(storeAddress, style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final Uri uri = Uri.parse(mapUrl);
                                          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps!')));
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
                                          child: Text('Map', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text('AVAILABLE ITEMS', style: GoogleFonts.inter(color: AppTheme.hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.restaurant, color: AppTheme.textSecondaryColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${product.quantity}x ${product.name}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textMainColor, fontSize: 14)),
                                          Text('Expires in ${product.remainingShelfLife} days', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          await _dbService.rejectDonation(donationId);
                                          if (context.mounted) setState(() {});
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.errorColor, 
                                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          backgroundColor: const Color(0xFFFEF2F2),
                                          elevation: 0,
                                        ),
                                        child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await _dbService.claimDonation(donationId, product.id, ngoId);
                                          if (context.mounted) {
                                            setState(() {});
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claimed! Awaiting Store Handover Approval.')));
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor, 
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                        child: Text('Claim Request', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
