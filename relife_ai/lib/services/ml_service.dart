import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MLService {
  // New Single Image prediction linked directly to FastAPI backend
  static Future<Map<String, dynamic>> predictFreshnessSingle(File imageFile) async {
    // Tries to pull from .env, but perfectly falls back to live huggingface production link globally
    final apiUrl = dotenv.env['FASTAPI_URL'] ?? 'https://irshad96-relife-ai-engine.hf.space/predict';

    try {
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      // FastAPI expects the file parameter to be named 'file'
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      final streamedResponse = await request.send();
      final responseData = await streamedResponse.stream.bytesToString();
      
      // print("ML API URL: $apiUrl");
      // print("ML API RESPONSE: $responseData");
      
      if (streamedResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(responseData);
        return {
           'success': true,
           'average_freshness': jsonResponse['average_freshness'] ?? 0.0,
           'fruit': jsonResponse['fruit'] ?? 'Unknown',
           'status': jsonResponse['status'] ?? 'Unknown',
           'total_detected': jsonResponse['total_detected'] ?? 0,
        };
      }
      return {'success': false, 'error': 'Server returned status ${streamedResponse.statusCode}'};
    } catch (e) {
      // print("ML API EXCEPTION: $e");
      return {'success': false, 'error': 'Failed to connect to Python Backend. Is FastAPI running?'};
    }
  }
}
