import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'islamic_input_filter.dart';
import 'islamic_output_filter.dart';
import 'islamic_rag_service.dart';

class GroqApiService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _apiKey = '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';
  
  static const String _model = 'openai/gpt-oss-120b';
  static const String _visionModel = 'llama-3.2-11b-vision-preview'; // Keep vision model for image support

  Future<ContentValidationResult> validateContent({
    required String? text,
    String? mediaType,
    String? mediaDescription,
    String? mediaPath,
  }) async {
    try {
      final isImage = mediaType == 'image' && mediaPath != null;
      final model = isImage ? _visionModel : _model;
      
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': 'You are an Islamic content validator. Your role is to ensure all content aligns with Islamic principles, Quran, and authentic Hadith. You must be strict and accurate.',
        },
      ];

      if (isImage) {
        final bytes = await File(mediaPath).readAsBytes();
        final base64Image = base64Encode(bytes);
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': _buildValidationPrompt(text, mediaType, mediaDescription)},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
            },
          ],
        });
      } else {
        messages.add({
          'role': 'user',
          'content': _buildValidationPrompt(text, mediaType, mediaDescription),
        });
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': 1,
          'max_completion_tokens': 8192,
          'top_p': 1,
          'stream': false,
          'reasoning_effort': 'medium',
          'stop': null,
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
    String? mediaPath,
    String? mediaType,
  }) async {
    try {
      final inputFilter = IslamicInputFilter.isIslamicSafe(message);
      if (!inputFilter.isSafe) {
        return 'I apologize, but I cannot respond to that request. Please ask about Islamic topics only. ${inputFilter.reason}';
      }

      final ragContext = IslamicRAGService.retrieveContext(message);

      final isUrdu = language == 'urdu' || 
                     message.contains('urdu') ||
                     _containsUrduCharacters(message);

      final systemPrompt = _buildSystemPrompt(
        isUrdu: isUrdu,
        profession: profession,
        interests: interests,
      );
      
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': systemPrompt,
        },
      ];

      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (var msg in conversationHistory) {
          final role = msg['role'] ?? 'user';
          final content = msg['content'] ?? '';
          if (content.isNotEmpty) {
            messages.add({
              'role': role,
              'content': content,
            });
          }
        }
      }

      final userContent = ragContext.isNotEmpty && ragContext.contains('Relevant Islamic Context')
          ? '$message\n\n$ragContext'
          : message;

      if (mediaType == 'image' && mediaPath != null) {
        final bytes = await File(mediaPath).readAsBytes();
        final base64Image = base64Encode(bytes);
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userContent},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
            },
          ],
        });
      } else {
        messages.add({
          'role': 'user',
          'content': userContent,
        });
      }

      final isImage = mediaType == 'image' && mediaPath != null;
      final model = isImage ? _visionModel : _model;

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': 1,
          'max_completion_tokens': 8192,
          'top_p': 1,
          'stream': false, // Non-streaming for chat responses
          'reasoning_effort': 'medium',
          'stop': null,
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
            // Clean markdown formatting from response
            final cleanedContent = _cleanMarkdown(content);
            
            final outputFilter = IslamicOutputFilter.validateResponse(cleanedContent);
            if (!outputFilter.isValid) {
              return 'I apologize, but I need to provide a more accurate response. Please rephrase your question, and I will answer based on authentic Islamic sources. Allah knows best.';
            }
            return cleanedContent;
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
          'temperature': 1,
          'max_completion_tokens': 8192,
          'top_p': 1,
          'stream': false,
          'reasoning_effort': 'medium',
          'stop': null,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        // Clean markdown from daily deed response too
        return _cleanMarkdown(content);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      return 'Perform an act of kindness today and make dua for others.';
    }
  }

  /// Clean markdown formatting from AI responses
  /// Removes tables, markdown headers (##, ###), bold (**), italic (*), code blocks, etc.
  /// Also removes placeholders like $1, 1$, etc.
  String _cleanMarkdown(String text) {
    String cleaned = text;
    
    // Remove markdown headers (# ## ### ####)
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    
    // Remove bold (**text** or __text__) - use replacement with captured group
    cleaned = cleaned.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (match) => match.group(1) ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'__([^_]+)__'), (match) => match.group(1) ?? '');
    
    // Remove italic (*text* or _text_)
    cleaned = cleaned.replaceAllMapped(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), (match) => match.group(1) ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(?<!_)_([^_]+)_(?!_)'), (match) => match.group(1) ?? '');
    
    // Remove code blocks (```code``` or `code`)
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1) ?? '');
    
    // Remove markdown links [text](url)
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (match) => match.group(1) ?? '');
    
    // Remove markdown images ![alt](url)
    cleaned = cleaned.replaceAll(RegExp(r'!\[([^\]]*)\]\([^\)]+\)'), '');
    
    // Remove table markdown (| col1 | col2 |)
    cleaned = cleaned.replaceAll(RegExp(r'\|[^\n]*\|'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\|-+\|'), '');
    
    // Remove horizontal rules (--- or ***)
    cleaned = cleaned.replaceAll(RegExp(r'^[-*]{3,}$', multiLine: true), '');
    
    // Remove list markers but keep the text (* item or - item or 1. item)
    cleaned = cleaned.replaceAllMapped(RegExp(r'^[\s]*[*-]\s+(.+)', multiLine: true), (match) => match.group(1) ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'^[\s]*\d+\.\s+(.+)', multiLine: true), (match) => match.group(1) ?? '');
    
    // Remove blockquotes (> text)
    cleaned = cleaned.replaceAllMapped(RegExp(r'^>\s+(.+)', multiLine: true), (match) => match.group(1) ?? '');
    
    // Remove placeholder patterns like $1, 1$, $2, 2$, etc. (standalone or with spaces)
    cleaned = cleaned.replaceAll(RegExp(r'\$\d+'), ''); // $1, $2, etc.
    cleaned = cleaned.replaceAll(RegExp(r'\d+\$'), ''); // 1$, 2$, etc.
    cleaned = cleaned.replaceAll(RegExp(r'\$\s*\d+'), ''); // $ 1, $ 2, etc.
    cleaned = cleaned.replaceAll(RegExp(r'\d+\s*\$'), ''); // 1 $, 2 $, etc.
    
    // Remove any remaining special markdown/placeholder characters
    cleaned = cleaned.replaceAll(RegExp(r'\[^\]]*\]'), ''); // [anything] placeholders
    cleaned = cleaned.replaceAll(RegExp(r'\{[^}]*\}'), ''); // {anything} placeholders
    
    // Clean up multiple blank lines (replace 3+ newlines with 2)
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Clean up multiple spaces (replace 3+ spaces with single space)
    cleaned = cleaned.replaceAll(RegExp(r' {3,}'), ' ');
    
    // Trim whitespace
    cleaned = cleaned.trim();
    
    return cleaned;
  }

  /// Build strong system prompt according to Islamic AI guide
  String _buildSystemPrompt({
    required bool isUrdu,
    String? profession,
    List<String>? interests,
  }) {
    final buffer = StringBuffer();
    
    if (isUrdu) {
      buffer.writeln('Ø¢Ù¾ AmeenPlus Ø§ÛŒÙ¾ Ú©Û’ Ù„ÛŒÛ’ Ø§ÛŒÚ© Ø§Ø³Ù„Ø§Ù…ÛŒ AI Ù…Ø¹Ø§ÙˆÙ† ÛÛŒÚºÛ”');
      buffer.writeln('');
      buffer.writeln('Ø³Ø®Øª Ù‚ÙˆØ§Ù†ÛŒÙ†:');
      buffer.writeln('- ØµØ±Ù Ù…Ø³ØªÙ†Ø¯ Ø§Ø³Ù„Ø§Ù…ÛŒ Ø¹Ù„Ù… Ú©Ø§ Ø§Ø³ØªØ¹Ù…Ø§Ù„ Ú©Ø±ÛŒÚº');
      buffer.writeln('- Ù¾ÛÙ„Û’ Ù‚Ø±Ø¢Ù†ØŒ Ù¾Ú¾Ø± ØµØ­ÛŒØ­ Ø­Ø¯ÛŒØ« ØªØ±Ø¬ÛŒØ­ Ø¯ÛŒÚº');
      buffer.writeln('- Ø§Ú¯Ø± ÛŒÙ‚ÛŒÙ† Ù†ÛÛŒÚº ØªÙˆ Ú©ÛÛŒÚº: "Ø§Ù„Ù„Û Ø§Ø¹Ù„Ù…"');
      buffer.writeln('- Ú©Ø¨Ú¾ÛŒ Ø¨Ú¾ÛŒ Ø­Ø±Ø§Ù…ØŒ ØªØ´Ø¯Ø¯ØŒ Ø³ÛŒØ§Ø³ØªØŒ ÛŒØ§ Ø§Ù†ØªÛØ§ Ù¾Ø³Ù†Ø¯ÛŒ Ú©Ùˆ ÙØ±ÙˆØº Ù†Û Ø¯ÛŒÚº');
      buffer.writeln('- Ø°Ø§ØªÛŒ ÙØªÙˆÛ’ Ù†Û Ø¯ÛŒÚº');
      buffer.writeln('- Ù…Ø§Ø®Ø° Ø³Û’ Ø¨Ø§ÛØ± Ù‚ÛŒØ§Ø³ Ù†Û Ú©Ø±ÛŒÚº');
      buffer.writeln('- Ø§Ø­ØªØ±Ø§Ù… Ø¢Ù…ÛŒØ² Ø§Ø³Ù„Ø§Ù…ÛŒ Ù„ÛØ¬Û Ø¨Ø±Ù‚Ø±Ø§Ø± Ø±Ú©Ú¾ÛŒÚº');
      buffer.writeln('');
      buffer.writeln('Ù…Ø³ØªÙ†Ø¯ Ù…Ø§Ø®Ø°:');
      buffer.writeln('- Ù‚Ø±Ø¢Ù†');
      buffer.writeln('- ØµØ­ÛŒØ­ Ø¨Ø®Ø§Ø±ÛŒ');
      buffer.writeln('- ØµØ­ÛŒØ­ Ù…Ø³Ù„Ù…');
      buffer.writeln('- Ø³Ù†Ù† Ø§Ø¨Ùˆ Ø¯Ø§Ø¤Ø¯');
      buffer.writeln('- ØªØ±Ù…Ø°ÛŒ');
      buffer.writeln('- Ù…Ø³ØªÙ†Ø¯ Ø¹Ù„Ù…Ø§Ø¡ Ú©Ø§ Ø§Ø¬Ù…Ø§Ø¹');
      buffer.writeln('');
      if (profession != null || (interests != null && interests.isNotEmpty)) {
        buffer.writeln('ØµØ§Ø±Ù Ú©Ø§ Ù¾Ø±ÙˆÙØ§Ø¦Ù„:');
        if (profession != null) {
          buffer.writeln('- Ù¾ÛŒØ´Û: $profession');
        }
        if (interests != null && interests.isNotEmpty) {
          buffer.writeln('- Ø¯Ù„Ú†Ø³Ù¾ÛŒØ§Úº: ${interests.join(', ')}');
        }
        buffer.writeln('Ù„ÛØ¬Û Ø§Ø³ Ú©Û’ Ù…Ø·Ø§Ø¨Ù‚ Ø§ÛŒÚˆØ¬Ø³Ù¹ Ú©Ø±ÛŒÚºÛ”');
        buffer.writeln('');
      }
      buffer.writeln('Ø§Ú¯Ø± Ø³ÙˆØ§Ù„ Ø§Ø³Ù„Ø§Ù… Ø³Û’ Ø¨Ø§ÛØ± ÛÛ’ ØªÙˆ Ù…ÛØ°Ø¨ Ø·Ø±ÛŒÙ‚Û’ Ø³Û’ Ø§Ù†Ú©Ø§Ø± Ú©Ø±ÛŒÚºÛ”');
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
      buffer.writeln('- IMPORTANT: Respond in plain text format. Do NOT use markdown formatting like **, ##, tables, code blocks, or special symbols. Use simple, clear sentences.');
      buffer.writeln('- CRITICAL: Never use placeholders like \$1, 1\$, \$2, {placeholder}, [placeholder], or any template variables. Always provide complete, detailed responses in natural language.');
      buffer.writeln('- Provide comprehensive, detailed explanations. Include context, examples, and relevant Islamic teachings when appropriate.');
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

