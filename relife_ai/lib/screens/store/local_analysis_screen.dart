import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/product.dart';
import '../../services/database_service.dart';
import '../../services/ml_service.dart';
import '../../core/app_theme.dart';

class LocalAnalysisScreen extends StatefulWidget {
  final Product product;
  const LocalAnalysisScreen({super.key, required this.product});

  @override
  State<LocalAnalysisScreen> createState() => _LocalAnalysisScreenState();
}

class _LocalAnalysisScreenState extends State<LocalAnalysisScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  
  bool _isProcessing = false;
  String _processingStatus = '';

  Future<void> _captureImage() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
    if (photo != null) {
      setState(() {
        _image = File(photo.path);
      });
    }
  }

  Future<void> _runServerAnalysis() async {
    if (_image == null) return;

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Connecting to YOLO/CNN Engine...';
    });

    try {
      setState(() => _processingStatus = 'Uploading Image to Python Server...');
      final result = await MLService.predictFreshnessSingle(_image!);

      if (result['success'] == true) {
        setState(() => _processingStatus = 'Syncing Results to Relife Cloud...');
        
        final double freshnessPercentage = result['average_freshness'];
        
        final db = DatabaseService();
        List<String> uploadedUrls = await db.uploadAnalysisPhotos([_image!]);

        // --- Dynamic Shelf Life Multiplier Logic ---
        double freshnessScore = freshnessPercentage;

        // 1. Get original tracking days
        int daysStored = 0;
        if (widget.product.mfgDate != null) {
          daysStored = DateTime.now().difference(widget.product.mfgDate!).inDays;
        } else {
          int totalShelf = widget.product.shelfLifeDays ?? widget.product.remainingShelfLife;
          daysStored = totalShelf - widget.product.remainingShelfLife;
        }
        if (daysStored < 0) daysStored = 0;

        // 2. Extrapolate calendar remaining

        // 4. Force Update Product Data!
        await db.updateProductScanOverrides(widget.product.id, freshnessScore);

        // 5. Save the standard sensor log for history
        await db.addSensorLog({
          'product_id': widget.product.id,
          'temperature': widget.product.temperature,
          'humidity': widget.product.humidity,
          'env_risk': widget.product.envRisk,
          'freshness_score': freshnessScore,
          'photo_urls': uploadedUrls,
          'recorded_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Analysis Complete 🚀', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text('Detected: ${result['fruit']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                   const SizedBox(height: 8),
                   Text('Status: ${result['status']}', style: TextStyle(color: result['status'] == 'Fresh' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Text('Freshness: ${(freshnessPercentage * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context, true); // close screen and trigger refresh
                  },
                  child: const Text('Done'),
                )
              ],
            )
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${result['error']}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('AI Engine Scan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.primaryGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 24),
                  Text(_processingStatus, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Processing via external FastAPI server', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Capture a clear photo of ${widget.product.name} to send to the CNN grading engine.', 
                    style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 16, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  Expanded(
                    child: GestureDetector(
                      onTap: _captureImage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _image != null ? AppTheme.primaryColor : Colors.grey.shade300, width: 2),
                          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.05), blurRadius: 20)],
                          image: _image != null
                              ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _image == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor, size: 48),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Tap to Open Camera', style: GoogleFonts.inter(color: AppTheme.textMainColor, fontWeight: FontWeight.w800, fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Text('Single image is enough', style: GoogleFonts.inter(color: AppTheme.hintColor, fontSize: 12)),
                                ],
                              )
                            : Container(
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Text('Tap to Retake Photo', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _image == null ? null : _runServerAnalysis,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome),
                        const SizedBox(width: 12),
                        Text('Run Python AI Analysis', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
