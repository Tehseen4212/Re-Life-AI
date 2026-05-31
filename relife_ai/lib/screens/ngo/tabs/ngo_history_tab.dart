import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';
import '../../../models/product.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/app_theme.dart';

class NGOHistoryTab extends StatefulWidget {
  const NGOHistoryTab({super.key});

  @override
  State<NGOHistoryTab> createState() => _NGOHistoryTabState();
}

class _NGOHistoryTabState extends State<NGOHistoryTab> {
  final DatabaseService _dbService = DatabaseService();

  Future<Uint8List> _generateCertificatePdf(Map<String, dynamic> donation, Product product, Map<String, dynamic>? store) async {
    final pdf = pw.Document();
    
    final date = DateTime.parse(donation['created_at']);
    final formattedDate = DateFormat('MMMM d, yyyy - h:mm a').format(date);
    final expiryDate = date.add(const Duration(days: 3));
    final formattedExpiry = DateFormat('MMMM d, yyyy - h:mm a').format(expiryDate);
    
    final uniqueId = "CERT-${donation['id'].toString().substring(0, 8).toUpperCase()}";
    final storeName = store?['store_name'] ?? 'Authorized Donor Store';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.deepPurple900, width: 4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('RELIFE DONATION HANDOVER CERTIFICATE', 
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(child: pw.Text('Certificate ID: $uniqueId', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
                pw.Divider(thickness: 2, color: PdfColors.deepPurple100),
                pw.SizedBox(height: 20),
                
                pw.Text('DONATION DETAILS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Date & Time: $formattedDate', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Donor / Store: $storeName', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Recipient: Authorized NGO Representative', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                
                pw.Text('ITEM SCHEDULE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.deepPurple50,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Item: ${product.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Qty: ${product.quantity}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                ),
                pw.SizedBox(height: 20),
                
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.red50, border: pw.Border.all(color: PdfColors.red)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CRITICAL VALIDITY NOTICE', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('Valid Until: $formattedExpiry (3 Days from Donation)', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                ),
                pw.SizedBox(height: 30),
                
                pw.Text('LEGAL DISCLAIMER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('1. The donated food items are deemed safe for consumption only within 3 days from the time of donation.', 
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.SizedBox(height: 4),
                    pw.Text('2. Any usage, consumption, or distribution of the food items beyond the specified validity period is done at the recipient\'s own risk.', 
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.SizedBox(height: 4),
                    pw.Text('3. The platform, its developers, and associated parties shall not be held liable or responsible for any health issues, damages, or consequences arising from the use of expired donated food.', 
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.SizedBox(height: 4),
                    pw.Text('4. The responsibility of timely consumption and proper storage lies entirely with the recipient after collection.', 
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
                
                pw.Spacer(),
                pw.Divider(color: PdfColors.deepPurple100),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 30),
                        pw.Container(width: 150, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 5),
                        pw.Text('Donor Digital Signature', style: const pw.TextStyle(fontSize: 10)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 30),
                        pw.Container(width: 150, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 5),
                        pw.Text('NGO Digital Signature', style: const pw.TextStyle(fontSize: 10)),
                      ]
                    ),
                  ]
                )
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  void _showCertificateDialog(BuildContext context, Map<String, dynamic> donation, Product product, Map<String, dynamic>? store) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Donation Certificate', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => _generateCertificatePdf(donation, product, store),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    pdfFileName: "relife_certificate_${donation['id'].toString().substring(0,8)}.pdf",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ngoId = context.read<AuthProvider>().user?.id;
    if (ngoId == null) return const Center(child: Text('Not Logged In'));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dbService.streamDonationHistory(ngoId),
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
                    Text('Donation History', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                    const SizedBox(height: 12),
                    Text('Track your active claims and completed handovers', style: GoogleFonts.inter(color: const Color(0xFFC4B5FD), fontSize: 13, fontWeight: FontWeight.w500)),
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
                            child: const Icon(Icons.history, size: 48, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text('No history yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMainColor)),
                          const SizedBox(height: 8),
                          Text('Accept requests to build your profile.', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final rawItem = items[index];
                        
                        // Safety Join Handling
                        final productData = rawItem['product'] is List 
                            ? (rawItem['product'] as List).first 
                            : rawItem['product'];
                        final storeData = rawItem['store'] is List 
                            ? (rawItem['store'] as List).first 
                            : rawItem['store'];

                        if (productData == null) return const SizedBox.shrink();

                        final Product product = Product.fromJson(productData);
                        final Map<String, dynamic>? store = storeData;
                        
                        final date = DateTime.parse(rawItem['created_at']);
                        final formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(date);
                        
                        final isRejected = rawItem['status'] == 'rejected';
                        final isClaimed = rawItem['status'] == 'claimed';
                        final isCompleted = rawItem['status'] == 'completed';
                        final reqType = rawItem['request_type'] == 'offer' ? 'OFFER' : 'DONATION';
                        final isOffer = reqType == 'OFFER';

                        String statusText = '';
                        Color statusColor = AppTheme.hintColor;
                        if (isRejected) { statusText = 'Rejected / Cancelled'; statusColor = AppTheme.errorColor; }
                        else if (isClaimed) { statusText = 'Claimed (Awaiting Handover)'; statusColor = AppTheme.warningColor; }
                        else if (isCompleted) { statusText = 'Handover Completed'; statusColor = AppTheme.successColor; }

                        final storeAddress = store?['location_address'] as String? ?? 'Unknown Location';
                        final mapUrl = store?['google_map_url'] as String? ?? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(storeAddress)}';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.05)),
                            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                                      child: Icon(isRejected ? Icons.cancel : (isCompleted ? Icons.done_all : Icons.handshake), color: statusColor, size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: isOffer ? AppTheme.warningColor : AppTheme.primaryColor, borderRadius: BorderRadius.circular(4)),
                                                child: Text(reqType, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(product.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMainColor), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('${product.quantity} items • $formattedDate', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor)),
                                          const SizedBox(height: 4),
                                          Text(statusText, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              if (!isRejected)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 14, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(storeAddress, style: GoogleFonts.inter(color: AppTheme.textMainColor, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () async {
                                            final Uri uri = Uri.parse(mapUrl);
                                            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch map.')));
                                            }
                                          },
                                          child: Text('Navigate', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                
                              if (isClaimed || isCompleted)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                        if (isClaimed)
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await _dbService.cancelDonation(rawItem['id']);
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation request cancelled.')));
                                          },
                                          icon: const Icon(Icons.undo, size: 16),
                                          label: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.errorColor, 
                                            side: const BorderSide(color: Color(0xFFFECACA)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        
                                      if (isCompleted)
                                        ElevatedButton.icon(
                                          onPressed: () => _showCertificateDialog(context, rawItem, product, store),
                                          icon: const Icon(Icons.workspace_premium, size: 16),
                                          label: Text('Certificate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.successColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            minimumSize: Size.zero,
                                            elevation: 0,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                            ],
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
