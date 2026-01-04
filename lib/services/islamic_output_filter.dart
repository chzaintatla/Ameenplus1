/// Output Filter Service - Post-filter to validate AI responses
/// for Islamic authenticity and safety
class IslamicOutputFilter {
  /// Validate if AI response is Islamically authentic
  /// Returns [OutputFilterResult] with validation status
  static OutputFilterResult validateResponse(String response) {
    // Check for speculative language (not allowed)
    if (_containsSpeculativeLanguage(response)) {
      return OutputFilterResult(
        isValid: false,
        reason: 'Response contains speculative language',
        confidence: 0.3,
      );
    }
    
    // Check for absolute claims without sources
    if (_containsUnsupportedClaims(response)) {
      return OutputFilterResult(
        isValid: false,
        reason: 'Response contains unsupported claims',
        confidence: 0.4,
      );
    }
    
    // Check for contradictions with Islam
    if (_containsContradictions(response)) {
      return OutputFilterResult(
        isValid: false,
        reason: 'Response contradicts Islamic principles',
        confidence: 0.2,
      );
    }
    
    // Check if response mentions sources (good sign)
    final hasSources = _mentionsSources(response);
    
    return OutputFilterResult(
      isValid: true,
      reason: hasSources 
          ? 'Response is valid and references sources'
          : 'Response is valid',
      confidence: hasSources ? 0.9 : 0.7,
    );
  }

  /// Check for speculative language (I think, probably, in my opinion)
  static bool _containsSpeculativeLanguage(String response) {
    final lowerResponse = response.toLowerCase();
    final speculativePatterns = [
      'i think',
      'probably',
      'in my opinion',
      'i believe',
      'i guess',
      'maybe',
      'perhaps',
      'might be',
    ];
    
    for (final pattern in speculativePatterns) {
      if (lowerResponse.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }

  /// Check for unsupported absolute claims
  static bool _containsUnsupportedClaims(String response) {
    final lowerResponse = response.toLowerCase();
    
    // Check for absolute claims without "Allah knows best" or sources
    final absolutePatterns = [
      'definitely',
      'certainly',
      'absolutely',
      'without doubt',
    ];
    
    final hasAbsolute = absolutePatterns.any((p) => lowerResponse.contains(p));
    final hasSource = _mentionsSources(response);
    final hasAllahKnowsBest = lowerResponse.contains('allah knows best') ||
                              lowerResponse.contains('الله أعلم');
    
    // If has absolute claim but no source or "Allah knows best", it's unsupported
    return hasAbsolute && !hasSource && !hasAllahKnowsBest;
  }

  /// Check for contradictions with Islamic principles
  static bool _containsContradictions(String response) {
    final lowerResponse = response.toLowerCase();
    
    final contradictionPatterns = [
      'islam allows',
      'islamic to',
      'halal to',
    ];
    
    // These patterns combined with haram topics indicate contradiction
    final haramTopics = [
      'drink alcohol',
      'gamble',
      'eat pork',
      'interest',
      'riba',
    ];
    
    for (final pattern in contradictionPatterns) {
      for (final topic in haramTopics) {
        if (lowerResponse.contains(pattern) && lowerResponse.contains(topic)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Check if response mentions Islamic sources
  static bool _mentionsSources(String response) {
    final lowerResponse = response.toLowerCase();
    
    final sourceKeywords = [
      'quran',
      'qur\'an',
      'hadith',
      'sahih',
      'bukhari',
      'muslim',
      'sunnah',
      'verse',
      'ayah',
      'surah',
    ];
    
    return sourceKeywords.any((keyword) => lowerResponse.contains(keyword));
  }
}

class OutputFilterResult {
  final bool isValid;
  final String reason;
  final double confidence; // 0.0 to 1.0

  OutputFilterResult({
    required this.isValid,
    required this.reason,
    required this.confidence,
  });
}

