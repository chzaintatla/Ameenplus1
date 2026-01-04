import 'dart:convert';
import 'package:http/http.dart' as http;
import 'islamic_input_filter.dart';
import 'islamic_output_filter.dart';
import 'islamic_rag_service.dart';

class GroqApiService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _apiKey = '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';
  
  static const String _model = 'llama-3.3-70b-versatile';

  Future<ContentValidationResult> validateContent({
    required String? text,
    String? mediaType,
    String? mediaDescription,
  }) async {
    try {
      final prompt = _buildValidationPrompt(text, mediaType, mediaDescription);
      
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an Islamic content validator. Your role is to ensure all content aligns with Islamic principles, Quran, and authentic Hadith. You must be strict and accurate.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.3,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return _parseValidationResponse(content);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      return ContentValidationResult(
        isValid: false,
        reason: 'Validation error: $e',
        confidence: 0.0,
      );
    }
  }

  Future<String> chat({
    required String message,
    List<Map<String, String>>? conversationHistory,
    String? profession,
    List<String>? interests,
    String? language,
  }) async {
    try {
      // STEP 1: INPUT FILTER - Pre-filter to block haram/non-Islamic content
      final inputFilter = IslamicInputFilter.isIslamicSafe(message);
      if (!inputFilter.isSafe) {
        return 'I apologize, but I cannot respond to that request. Please ask about Islamic topics only. ${inputFilter.reason}';
      }

      // STEP 2: RAG - Retrieve relevant Islamic context
      final ragContext = IslamicRAGService.retrieveContext(message);
      
      // STEP 3: Detect language
      final isUrdu = language == 'urdu' || 
                     message.toLowerCase().contains('اردو') || 
                     message.contains('urdu') ||
                     _containsUrduCharacters(message);
      
      // STEP 4: Build strong system prompt (as per guide)
      final systemPrompt = _buildSystemPrompt(
        isUrdu: isUrdu,
        profession: profession,
        interests: interests,
      );
      
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': systemPrompt,
        },
      ];

      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        messages.addAll(conversationHistory);
      }

      // Build user message with RAG context
      final userMessage = ragContext.isNotEmpty && ragContext.contains('Relevant Islamic Context')
          ? '$message\n\n$ragContext'
          : message;

      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && 
            data['choices'].isNotEmpty && 
            data['choices'][0]['message'] != null) {
          final content = data['choices'][0]['message']['content'] as String?;
          if (content != null && content.isNotEmpty) {
            // STEP 5: OUTPUT FILTER - Post-filter to validate response
            final outputFilter = IslamicOutputFilter.validateResponse(content);
            if (!outputFilter.isValid) {
              // If response is invalid, return a safe fallback
              return 'I apologize, but I need to provide a more accurate response. Please rephrase your question, and I will answer based on authentic Islamic sources. Allah knows best.';
            }
            return content;
          } else {
            throw Exception('Empty response from API');
          }
        } else {
          throw Exception('Invalid response format from API');
        }
      } else {
        final errorBody = response.body;
        throw Exception('API Error: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        return 'Request timeout. Please check your internet connection and try again.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup')) {
        return 'Network error. Please check your internet connection and try again.';
      } else {
        return 'I apologize, but I encountered an error: ${e.toString()}. Please try again.';
      }
    }
  }

  Future<String> generateDailyDeed({
    required String profession,
    required List<String> interests,
    required int activityLevel,
  }) async {
    try {
      final prompt = '''
Generate a personalized Islamic daily deed recommendation for:
- Profession: $profession
- Interests: ${interests.join(', ')}
- Activity Level: $activityLevel

Provide ONE specific, actionable Islamic deed that aligns with their profession and interests. Include:
1. The deed name
2. Brief description
3. How it relates to their profession/interests
4. Expected reward/benefit

Format: [Deed Name] - [Description] - [Connection] - [Benefit]
''';

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an Islamic guidance assistant that creates personalized daily deed recommendations based on user profiles.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.8,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      return 'Perform an act of kindness today and make dua for others.';
    }
  }

  /// Build strong system prompt according to Islamic AI guide
  String _buildSystemPrompt({
    required bool isUrdu,
    String? profession,
    List<String>? interests,
  }) {
    final buffer = StringBuffer();
    
    if (isUrdu) {
      buffer.writeln('آپ AmeenPlus ایپ کے لیے ایک اسلامی AI معاون ہیں۔');
      buffer.writeln('');
      buffer.writeln('سخت قوانین:');
      buffer.writeln('- صرف مستند اسلامی علم کا استعمال کریں');
      buffer.writeln('- پہلے قرآن، پھر صحیح حدیث ترجیح دیں');
      buffer.writeln('- اگر یقین نہیں تو کہیں: "اللہ اعلم"');
      buffer.writeln('- کبھی بھی حرام، تشدد، سیاست، یا انتہا پسندی کو فروغ نہ دیں');
      buffer.writeln('- ذاتی فتوے نہ دیں');
      buffer.writeln('- ماخذ سے باہر قیاس نہ کریں');
      buffer.writeln('- احترام آمیز اسلامی لہجہ برقرار رکھیں');
      buffer.writeln('');
      buffer.writeln('مستند ماخذ:');
      buffer.writeln('- قرآن');
      buffer.writeln('- صحیح بخاری');
      buffer.writeln('- صحیح مسلم');
      buffer.writeln('- سنن ابو داؤد');
      buffer.writeln('- ترمذی');
      buffer.writeln('- مستند علماء کا اجماع');
      buffer.writeln('');
      if (profession != null || (interests != null && interests.isNotEmpty)) {
        buffer.writeln('صارف کا پروفائل:');
        if (profession != null) {
          buffer.writeln('- پیشہ: $profession');
        }
        if (interests != null && interests.isNotEmpty) {
          buffer.writeln('- دلچسپیاں: ${interests.join(', ')}');
        }
        buffer.writeln('لہجہ اس کے مطابق ایڈجسٹ کریں۔');
        buffer.writeln('');
      }
      buffer.writeln('اگر سوال اسلام سے باہر ہے تو مہذب طریقے سے انکار کریں۔');
    } else {
      buffer.writeln('You are an Islamic AI assistant for the AmeenPlus app.');
      buffer.writeln('');
      buffer.writeln('STRICT RULES:');
      buffer.writeln('- Answer ONLY using authentic Islamic knowledge');
      buffer.writeln('- Prefer Quran first, then Sahih Hadith');
      buffer.writeln('- If unsure, say: "Allah knows best"');
      buffer.writeln('- Never promote haram, violence, politics, or extremism');
      buffer.writeln('- Do not give personal fatwas');
      buffer.writeln('- Do not speculate beyond sources');
      buffer.writeln('- Maintain respectful Islamic tone');
      buffer.writeln('');
      buffer.writeln('SOURCES ALLOWED:');
      buffer.writeln('- Quran');
      buffer.writeln('- Sahih Bukhari');
      buffer.writeln('- Sahih Muslim');
      buffer.writeln('- Sunan Abu Dawood');
      buffer.writeln('- Tirmidhi');
      buffer.writeln('- Authentic scholarly consensus');
      buffer.writeln('');
      if (profession != null || (interests != null && interests.isNotEmpty)) {
        buffer.writeln('User profile:');
        if (profession != null) {
          buffer.writeln('- Profession: $profession');
        }
        if (interests != null && interests.isNotEmpty) {
          buffer.writeln('- Interests: ${interests.join(', ')}');
        }
        buffer.writeln('Adjust tone accordingly.');
        buffer.writeln('');
      }
      buffer.writeln('If a question is outside Islam, politely refuse.');
    }
    
    return buffer.toString();
  }

  String _buildValidationPrompt(String? text, String? mediaType, String? mediaDescription) {
    final buffer = StringBuffer();
    buffer.writeln('Analyze the following content and determine if it is:');
    buffer.writeln('1. Islamic and aligned with Quran & Hadith');
    buffer.writeln('2. Free from haram, inappropriate, or non-Islamic material');
    buffer.writeln('3. Suitable for an Islamic social media platform');
    buffer.writeln('');
    buffer.writeln('Content to validate:');
    
    if (text != null && text.isNotEmpty) {
      buffer.writeln('Text: $text');
    }
    
    if (mediaType != null) {
      buffer.writeln('Media Type: $mediaType');
    }
    
    if (mediaDescription != null && mediaDescription.isNotEmpty) {
      buffer.writeln('Media Description: $mediaDescription');
    }
    
    buffer.writeln('');
    buffer.writeln('Respond in JSON format:');
    buffer.writeln('{"isValid": true/false, "reason": "explanation", "confidence": 0.0-1.0}');
    
    return buffer.toString();
  }

  ContentValidationResult _parseValidationResponse(String response) {
    try {
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return ContentValidationResult(
          isValid: json['isValid'] as bool? ?? false,
          reason: json['reason'] as String? ?? 'Unknown reason',
          confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        );
      }
      
      // Fallback parsing
      final isValid = !response.toLowerCase().contains('invalid') &&
          !response.toLowerCase().contains('not islamic') &&
          !response.toLowerCase().contains('haram') &&
          !response.toLowerCase().contains('inappropriate');
      
      return ContentValidationResult(
        isValid: isValid,
        reason: response,
        confidence: isValid ? 0.8 : 0.2,
      );
    } catch (e) {
      return ContentValidationResult(
        isValid: false,
        reason: 'Failed to parse validation response: $e',
        confidence: 0.0,
      );
    }
  }

  bool _containsUrduCharacters(String text) {
    final urduPattern = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return urduPattern.hasMatch(text);
  }
}

class ContentValidationResult {
  final bool isValid;
  final String reason;
  final double confidence; // 0.0 to 1.0

  ContentValidationResult({
    required this.isValid,
    required this.reason,
    required this.confidence,
  });
}

