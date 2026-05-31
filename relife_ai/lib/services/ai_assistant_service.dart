import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

class AIAssistantService {
  late final String _apiKey;

  AIAssistantService() {
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) throw Exception('No API Key found in .env');
  }

  Future<String> askQuestion(String userId, String question) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/brain_cache.txt');
      String fileContext = "";
      if (await file.exists()) {
        fileContext = await file.readAsString();
      }

      String systemPrompt = '''
You are "Relife AI", a highly intelligent voice assistant built into an app for store owners.
You act like J.A.R.V.I.S and speak in Hinglish or English based on user's query.

Below is your MASTER BRAIN FILE tracking the live DB cache:
$fileContext

Rules:
1. Answer store-related queries accurately based on the above Brain File. Talk normally.
2. If the user asks general-knowledge questions, USE YOUR WIDE KNOWLEDGE to answer them flawlessly.
3. NEVER USE MARKDOWN. Do not use asterisks (**) or hashes (#). Output clean, plain text only.
4. Reply concisely but intelligently to Q&A.
''';
      
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "system_instruction": {
            "parts": {"text": systemPrompt}
          },
          "contents": [{
            "parts": [{"text": question}]
          }],
          "generationConfig": {
            "temperature": 0.7
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? 'No text generated.';
      } else if (response.statusCode == 429) {
        return '✨ AI Daily Limit reached. Please wait or try later.';
      } else {
        return '✨ Connection Error: ${response.statusCode}. Please try again.';
      }
    } catch (e) {
      return 'Error connecting to brain: $e';
    }
  }

  Future<String> getProductHealthInsight(String productName, String category, int remainingDays, double lifePercentage, double? temp, double? humidity, double? freshnessScore, String riskClassification) async {
    try {
      String systemPrompt = '''
You are "Relife AI Health Doctor". Give extremely SHORT and DIRECT insights.
Analyze the following LIVE metrics:
Product: $productName ($category)
Life: $remainingDays days ($lifePercentage%)
Temperature: ${temp != null ? '$temp°C' : 'Data Missing'}
Humidity: ${humidity != null ? '$humidity%' : 'Data Missing'}
Freshness: ${freshnessScore != null ? '$freshnessScore' : 'Data Missing'}
Calculated Risk: $riskClassification

Your Output MUST be exactly 2 short bullet points (Use simple dashes '-' not markdown asterisks):
- Factor: Compare actual Temp/Humidity vs Ideal condition for this product. 
- Action: ONE short direct step (e.g. "Move to cooler immediately").
NEVER USE MARKDOWN. Do not use asterisks (**) or hashes (#). Output clean, plain text only.
Do not write paragraphs. Keep it under 40 words total.
''';
      
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "system_instruction": {
            "parts": {"text": systemPrompt}
          },
          "contents": [{
            "parts": [{"text": 'Analyze this product and provide the actionable health doctor report.'}]
          }],
          "generationConfig": {
            "temperature": 0.4
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? 'No text generated.';
      } else if (response.statusCode == 429) {
        return '✨ AI Limit Exhausted. Please try later.';
      } else {
        return '✨ Fetch Failed: ${response.statusCode}.';
      }
    } catch (e) {
      return 'Error analyzing: $e';
    }
  }
}

