import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user_profile.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';
import '../../../utils/risk_calculator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/app_theme.dart';

class DonationsTab extends StatefulWidget {
  const DonationsTab({super.key});

  @override
  State<DonationsTab> createState() => _DonationsTabState();
}

class _DonationsTabState extends State<DonationsTab> {
  final DatabaseService _dbService = DatabaseService();

  Future<void> _generateAndPrintPdf(Map<String, dynamic> item, UserProfile? storeProfile) async {
    final rawProduct = item['product'] is List ? (item['product'] as List).first : item['product'];
    final product = Product.fromJson(rawProduct);
    final ngo = item['ngo'] is List ? (item['ngo'] as List).first : item['ngo'];
    final rawDate = item['created_at'];
    final donationDate = rawDate != null ? DateTime.parse(rawDate) : DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy').format(donationDate);
    final receiptNo = "RL-${item['id'].toString().substring(0, 8).toUpperCase()}";

    final storeName = storeProfile?.storeName ?? 'Store Owner';
    final ownerName = storeProfile?.email.split('@')[0] ?? 'Owner';
    final donorAddress = storeProfile?.locationAddress ?? 'Not specified';
    final donorContact = storeProfile?.contactNumber ?? 'Not specified';

    final ngoName = ngo?['store_name'] ?? 'Relife Affiliated NGO';
    final ngoAddress = ngo?['location_address'] ?? 'Official NGO Headquarters, India';
    final ngoContact = ngo?['contact_number'] ?? 'Contact NGO Office';
    final ngoPan = "RFAID1234N"; // Placeholder, usually would come from NGO profile
    final ngo80G = "80G/RELIFE/2026/001";

    final totalValue = product.price * product.quantity;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // NGO Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(ngoName.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900)),
                          pw.Text(ngoAddress, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("PAN: $ngoPan | 80G No: $ngo80G", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("Contact: $ngoContact", style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("DONATION RECEIPT", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 16),

                  // Receipt Meta
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Receipt No: $receiptNo", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Date: $formattedDate"),
                    ],
                  ),
                  pw.SizedBox(height: 24),

                  // Donor Section
                  pw.Text("DONOR DETAILS", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Bullet(text: "Store Name: $storeName"),
                        pw.Bullet(text: "Owner Name: $ownerName"),
                        pw.Bullet(text: "Address: $donorAddress"),
                        pw.Bullet(text: "Contact: $donorContact"),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 24),

                  // Donation Table
                  pw.Text("DONATION DETAILS", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Item Description", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Category", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Qty", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Approx Value (INR)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(product.name)),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(product.category)),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("${product.quantity}")),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Rs. ${totalValue.toStringAsFixed(2)}")),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("Total Value: Rs. ${totalValue.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ),
                  pw.SizedBox(height: 32),

                  // Declaration
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("DECLARATION:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          "This is to certify that the above donation has been received by $ngoName. The organization confirms that the items received will be utilized solely for charitable purposes.",
                          style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                  pw.Spacer(),

                  // Signatures
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(width: 120, height: 1, color: PdfColors.black),
                          pw.Text("Authorized Signatory", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(ngoName, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(width: 80, height: 80, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300))),
                          pw.Text("NGO STAMP", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Center(child: pw.Text("Generated via Relife AI Platform", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400))),
                ],
              );
            },
          ),
        );
        return doc.save();
      },
    );
  }

  void _showReceiptDialog(BuildContext context, Map<String, dynamic> item, UserProfile? storeProfile) {
    final rawProduct = item['product'] is List ? (item['product'] as List).first : item['product'];
    final product = Product.fromJson(rawProduct);
    final ngo = item['ngo'] is List ? (item['ngo'] as List).first : item['ngo'];
    final rawDate = item['created_at'];
    final donationDate = rawDate != null ? DateTime.parse(rawDate) : DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy').format(donationDate);

    final storeName = storeProfile?.storeName ?? 'Store Owner';
    final ownerName = storeProfile?.email.split('@')[0] ?? 'Owner';
    final ngoName = ngo?['store_name'] ?? 'Relife Affiliated NGO';
    final ngoAddress = ngo?['location_address'] ?? 'NGO Headquarters';
    
    final totalValue = product.price * product.quantity;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.1), blurRadius: 30)],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.verified_user_rounded, color: AppTheme.successColor, size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text('OFFICIAL RECEIPT', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.5, color: AppTheme.primaryColor)),
                        const SizedBox(height: 4),
                        Text("Section 80G Certified", style: GoogleFonts.inter(color: AppTheme.successColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildReceiptRow('RECEIPT NO', "RL-${item['id'].toString().substring(0, 8).toUpperCase()}"),
                  _buildReceiptRow('DATE OF ISSUE', formattedDate),
                  
                  const Divider(height: 40, color: Color(0xFFF3F4F6)),
  
                  Text('DONOR DETAILS', style: GoogleFonts.inter(color: AppTheme.hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Text(storeName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMainColor)),
                  Text('Owner: $ownerName', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),
                  
                  const SizedBox(height: 24),
  
                  Text('NGO DETAILS', style: GoogleFonts.inter(color: AppTheme.hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Text(ngoName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                  Text(ngoAddress, style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),

                  const Divider(height: 40, color: Color(0xFFF3F4F6)),

                  Text('CONTRIBUTION', style: GoogleFonts.inter(color: AppTheme.hintColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textMainColor)),
                          Text('${product.quantity} units | ${product.category}', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),
                        ],
                      ),
                      Text('₹ ${totalValue.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.successColor)),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(16)),
                    child: Text(
                        'Declaration: This donation is eligible for tax deduction under Section 80G of the Income Tax Act, 1961.',
                        style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _generateAndPrintPdf(item, storeProfile),
                          icon: const Icon(Icons.file_download_rounded, size: 18),
                          label: Text('Download', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor, 
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.textMainColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: AppTheme.hintColor, fontSize: 10, fontWeight: FontWeight.w800)),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textMainColor)),
        ],
      ),
    );
  }


  Widget _buildProductCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 12),
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: AppTheme.errorColor.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textMainColor), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${RiskCalculator.calculateProductLifePercentage(product).toStringAsFixed(0)}% life • Rapid decay', style: GoogleFonts.inter(color: AppTheme.errorColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await _dbService.createDonation(product.id, product.storeOwnerId, requestType: 'offer');
                    } catch (_) { /* ignore */ }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warningColor, 
                    side: const BorderSide(color: AppTheme.warningColor),
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Offer', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _dbService.createDonation(product.id, product.storeOwnerId, requestType: 'donation');
                    } catch (_) { /* ignore */ }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    minimumSize: const Size(0, 36),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Donate', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return const Center(child: Text('Not Logged In'));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Product>>(
        stream: _dbService.streamStoreProducts(userId),
        initialData: DatabaseService.cachedGlobalProducts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          
          final products = snapshot.data ?? [];
          final highRiskProducts = products.where((p) => p.status == 'active' && RiskCalculator.calculateProductLifePercentage(p) <= 50).toList();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _dbService.streamDonationHistoryForStore(userId),
            builder: (context, donSnap) {
              if (donSnap.connectionState == ConnectionState.waiting && !donSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }

              final historyItems = donSnap.data ?? [];
              final completedItems = historyItems.where((i) => i['status'] == 'completed').toList();
              final acceptedItems = historyItems.where((i) => i['status'] == 'claimed' || i['status'] == 'completed').toList();
              
              int totalDonatedKg = 0;
              for (var req in completedItems) {
                final productData = req['product'] is List ? (req['product'] as List).first : req['product'];
                totalDonatedKg += (productData?['quantity'] ?? 0) as int;
              }

              final bool isBadgeUnlocked = totalDonatedKg >= 80;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
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
                      child: Text('NGO Network\n& Donations', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isBadgeUnlocked ? const Color(0xFFDCFCE7) : Colors.white, 
                              borderRadius: BorderRadius.circular(20), 
                              border: Border.all(color: isBadgeUnlocked ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB)),
                              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isBadgeUnlocked ? AppTheme.successColor : AppTheme.backgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.workspace_premium, color: isBadgeUnlocked ? Colors.white : AppTheme.hintColor, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Green Store Certified', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: isBadgeUnlocked ? Colors.green.shade800 : AppTheme.textMainColor)),
                                      const SizedBox(height: 4),
                                      Text(
                                        isBadgeUnlocked 
                                        ? 'You saved ${totalDonatedKg}kg of food and unlocked tax benefits!' 
                                        : 'Donate ${80 - totalDonatedKg}kg more to unlock store badges & benefits!', 
                                        style: GoogleFonts.inter(color: isBadgeUnlocked ? Colors.green.shade700 : AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          Text('ACTION SUGGESTED ITEMS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text('These items have <= 50% life left.', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12)),
                          const SizedBox(height: 16),

                          if (highRiskProducts.isEmpty)
                            Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No critical items suggested.', style: GoogleFonts.inter(color: AppTheme.hintColor, fontWeight: FontWeight.bold))))
                          else
                            SizedBox(
                              height: 160,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: highRiskProducts.length,
                                itemBuilder: (context, index) {
                                  return _buildProductCard(highRiskProducts[index]);
                                },
                              ),
                            ),

                          const SizedBox(height: 32),
                          Text('ACCEPTED DONATIONS (NGO TRACK)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text('Real-time tracking of NGOs claiming items.', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12)),
                          const SizedBox(height: 16),

                          if (acceptedItems.isEmpty)
                             Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No accepted requests yet.', style: GoogleFonts.inter(color: AppTheme.hintColor, fontWeight: FontWeight.bold))))
                          else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: acceptedItems.length,
                                itemBuilder: (context, idx) {
                                  final rawItem = acceptedItems[idx];
                                  final rawProduct = rawItem['product'] is List ? (rawItem['product'] as List).first : rawItem['product'];
                                  final product = Product.fromJson(rawProduct);
                                  final requestType = rawItem['request_type'] == 'offer' ? 'OFFER' : 'DONATION';
                                  final status = rawItem['status'];
                                  final ngo = rawItem['ngo'] is List ? (rawItem['ngo'] as List).first : rawItem['ngo']; 

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      onTap: status == 'completed' ? null : () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) {
                                            final ngoName = ngo != null ? (ngo['store_name'] ?? 'Unknown NGO') : 'Unknown NGO';
                                            final ngoContact = ngo != null ? (ngo['contact_number'] ?? 'N/A') : 'N/A';
                                            final ngoAddress = ngo != null ? (ngo['location_address'] ?? 'N/A') : 'N/A';

                                            return AlertDialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                              title: Text('Review Claim Request', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppTheme.textMainColor)),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('NGO: $ngoName', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                                                      const SizedBox(height: 8),
                                                      const Divider(color: Color(0xFFF3F4F6)),
                                                      const SizedBox(height: 8),
                                                      Text('Contact: $ngoContact', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),
                                                      const SizedBox(height: 4),
                                                      Text('Address: $ngoAddress', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),
                                                const SizedBox(height: 16),
                                                Text('Handover the products to this NGO?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textMainColor)),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () async {
                                                  Navigator.pop(ctx);
                                                  await _dbService.rejectDonation(rawItem['id']);
                                                },
                                                child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  Navigator.pop(ctx);
                                                  await _dbService.approveDonation(rawItem['id']);
                                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Handover Processed.')));
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                child: Text('Approve', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                              )
                                            ],
                                            );
                                          },
                                        );
                                      },
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: status == 'completed' ? AppTheme.successColor.withValues(alpha: 0.1) : const Color(0xFFE0F2FE), 
                                          shape: BoxShape.circle
                                        ),
                                        child: Icon(status == 'completed' ? Icons.done_all : Icons.touch_app, color: status == 'completed' ? AppTheme.successColor : const Color(0xFF0284C7), size: 20)
                                      ),
                                      title: Text('[$requestType] ${product.name}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textMainColor)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(status == 'completed' ? 'Handover completed successfully' : 'Awaiting Review (Tap to view NGO)', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
                                      ),
                                      trailing: status == 'completed'
                                          ? TextButton.icon(
                                              onPressed: () => _showReceiptDialog(context, acceptedItems[idx], context.read<AuthProvider>().profile),
                                              icon: const Icon(Icons.receipt_long, color: AppTheme.successColor, size: 16),
                                              label: Text('Receipt', style: GoogleFonts.inter(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                            )
                                          : const Icon(Icons.chevron_right, size: 20, color: AppTheme.hintColor),
                                    ),
                                  );
                                },
                              ),
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
