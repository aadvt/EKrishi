import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../models/produce_result.dart';
import '../utils/exceptions.dart';

class ProduceService {
  Future<ProduceResult> identifyProduce(
    File imageFile,
    String district,
    String state,
  ) async {
    final String? apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw NetworkException("API key not found");
    }

    final String currentMonth = DateFormat('MMMM').format(DateTime.now());

    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final String prompt =
          """
      You are an expert agricultural quality grader and pricing assistant for Indian farmers.

      Carefully examine this image and do two things:
      1. Identify the fruit or vegetable
      2. Assess its physical condition and grade it — then use that grade 
         to calculate a fair price

      Farmer location: $district, $state, India
      Current month: $currentMonth

      QUALITY GRADING INSTRUCTIONS:
      Look carefully at the produce for:
      - Color: is it vibrant and even, or dull/patchy/yellowing?
      - Surface: any blemishes, bruises, spots, cracks, or damage?
      - Firmness appearance: does it look firm and fresh or soft/wilting?
      - Ripeness stage: is it unripe, fresh, ripe, overripe, or spoiled?
      - Overall grade: Grade A (excellent), Grade B (good), Grade C (poor)

      PRICING INSTRUCTIONS:
      - Start with the typical modal mandi price for this produce in 
        $state, India in $currentMonth
      - Apply quality multiplier:
          Grade A = base price × 1.15
          Grade B = base price × 1.00  
          Grade C = base price × 0.80
      - Factor in seasonal supply/demand for $currentMonth in $state

      Respond ONLY with this exact JSON, no markdown, no extra text:
      {
        \"name_english\": \"Tomato\",
        \"name_kannada\": \"ಟೊಮೆಟೊ\",
        \"confidence\": 0.95,
        \"category\": \"vegetable\",
        \"ripeness\": \"ripe\",
        \"grade\": \"A\",
        \"grade_reasoning\": \"Vibrant red color, firm appearance, no visible blemishes\",
        \"price_min_per_kg\": 18,
        \"price_max_per_kg\": 28,
        \"price_fair_per_kg\": 22,
        \"price_reasoning\": \"Grade A tomatoes in peak Karnataka season. Good color and firmness justify premium pricing.\",
        \"price_confidence\": \"high\"
      }

      If the image does not contain a fruit or vegetable, respond with 
      only: {\"error\": \"not_produce\"}
      """;

      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                    {
                      'inline_data': {
                        'mime_type': 'image/jpeg',
                        'data': base64Image,
                      },
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw NetworkException("HTTP Status ${response.statusCode}");
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      String text = data['candidates'][0]['content']['parts'][0]['text'];

      // Strip markdown code blocks if present
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      final Map<String, dynamic> resultJson = jsonDecode(text);

      if (resultJson.containsKey('error') &&
          resultJson['error'] == 'not_produce') {
        throw NotProduceException();
      }

      return ProduceResult.fromJson(resultJson);
    } on SocketException {
      throw NetworkException("No internet connection");
    } on FormatException {
      throw NetworkException("Failed to parse AI response");
    } on NotProduceException {
      rethrow;
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }
}
