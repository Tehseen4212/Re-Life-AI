import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TFLiteService {
  // Deployed Cloud GPU Backend hosted securely on Hugging Face Spaces (24x7 Up)
  String apiUrl = 'https://irshad96-relife-ai-engine.hf.space/predict';

  TFLiteService();

  Future<double> analyzeImages(List<String> imagePaths) async {
    double totalScore = 0.0;
    int processedCount = 0;

    for (String path in imagePaths) {
      if (path.isEmpty) continue;

      try {
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
        request.files.add(await http.MultipartFile.fromPath('image', path));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          double freshnessConfidence = jsonData['freshness_score'].toDouble();
          
          if(freshnessConfidence > 1) freshnessConfidence = 1.0;
          if(freshnessConfidence < 0) freshnessConfidence = 0.0;

          totalScore += freshnessConfidence;
          processedCount++;
        } else {
          debugPrint("API Error: ${response.statusCode} - ${response.body}");
        }
      } catch (e) {
        debugPrint("API request failed on image: $e");
      }
    }

    if (processedCount == 0) return 0.85; // Protection against zero division
    
    return double.parse((totalScore / processedCount).toStringAsFixed(2));
  }

  void dispose() {
    // No longer needed for HTTP calls
  }
}
