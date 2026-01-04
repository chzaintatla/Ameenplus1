import 'dart:io';
import 'groq_api_service.dart';
import 'islamic_input_filter.dart';
import 'package:path/path.dart' as path;

class AIContentValidationService {
  final GroqApiService _groqService = GroqApiService();

  Future<ValidationResult> validatePost({
    required String? text,
    String? mediaPath,
    String? mediaType,
  }) async {
    try {
      String? mediaDescription;

      if (mediaPath != null && mediaType != null) {
        mediaDescription = await _describeMedia(mediaPath, mediaType);
      }

      final result = await _groqService.validateContent(
        text: text,
        mediaType: mediaType,
        mediaDescription: mediaDescription,
      );

      return ValidationResult(
        isValid: result.isValid,
        reason: result.reason,
        confidence: result.confidence,
        requiresReview: result.confidence < 0.7,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        reason: 'Validation error: $e',
        confidence: 0.0,
        requiresReview: true,
      );
    }
  }

  Future<ChatValidationResult> validateChatMessage(String message) async {
    try {
      // First, use input filter for quick keyword-based check
      final inputFilter = IslamicInputFilter.isIslamicSafe(message);
      if (!inputFilter.isSafe) {
        return ChatValidationResult(
          isIslamic: false,
          reason: inputFilter.reason,
        );
      }

      // Then, use AI to check if it's about Islamic topics
      final prompt = '''
Is this message asking about Islamic topics, seeking Islamic guidance, or discussing Islamic matters?
Message: "$message"

Respond with JSON: {"isIslamic": true/false, "reason": "explanation"}
If the message is about non-Islamic topics, respond with isIslamic: false.
''';

      final response = await _groqService.chat(message: prompt);

      final isIslamic = !response.toLowerCase().contains('not islamic') &&
          !response.toLowerCase().contains('non-islamic') &&
          !response.toLowerCase().contains('false');

      return ChatValidationResult(
        isIslamic: isIslamic,
        reason: isIslamic ? 'Message is about Islamic topics' : 'Message contains non-Islamic topics',
      );
    } catch (e) {
      return ChatValidationResult(
        isIslamic: false,
        reason: 'Validation error: $e',
      );
    }
  }

  Future<String?> _describeMedia(String mediaPath, String mediaType) async {
    final fileName = path.basename(mediaPath);
    final extension = path.extension(mediaPath).toLowerCase();

    switch (mediaType) {
      case 'image':
        return 'Image file: $fileName (${extension})';
      case 'video':
        return 'Video file: $fileName (${extension})';
      case 'pdf':
        return 'PDF document: $fileName';
      case 'audio':
        return 'Audio file: $fileName (${extension})';
      case 'document':
        return 'Document file: $fileName (${extension})';
      default:
        return 'Media file: $fileName';
    }
  }
}

class ValidationResult {
  final bool isValid;
  final String reason;
  final double confidence;
  final bool requiresReview;

  ValidationResult({
    required this.isValid,
    required this.reason,
    required this.confidence,
    required this.requiresReview,
  });
}

class ChatValidationResult {
  final bool isIslamic;
  final String reason;

  ChatValidationResult({
    required this.isIslamic,
    required this.reason,
  });
}

