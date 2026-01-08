/// Input Filter Service - Pre-filter to block haram/non-Islamic content
/// before sending to Groq API
class IslamicInputFilter {
  /// Banned keywords that indicate non-Islamic or haram content
  static const List<String> _bannedKeywords = [
    // Haram content
    'porn',
    'pornography',
    'nudity',
    'nude',
    'sex',
    'sexual',
    'gambling',
    'casino',
    'bet',
    'alcohol',
    'wine',
    'beer',
    'drug',
    'cannabis',
    'marijuana',
    
    // Violence & extremism
    'kill',
    'murder',
    'terror',
    'terrorism',
    'extremism',
    'bomb',
    'violence',
    'attack',
    'assassinate',
    
    // Political extremism
    'political extremism',
    'hate speech',
    'racism',
    
    // Non-Islamic promotion
    'atheism',
    'atheist',
    'blasphemy',
    'blasphemous',
  ];

  /// Check if text is Islamic-safe (pre-filter)
  /// Returns [InputFilterResult] with safety status
  static InputFilterResult isIslamicSafe(String text) {
    final lowerText = text.toLowerCase();
    
    // Check for banned keywords
    for (final keyword in _bannedKeywords) {
      if (lowerText.contains(keyword)) {
        return InputFilterResult(
          isSafe: false,
          reason: 'Content contains inappropriate material',
          blockedKeyword: keyword,
        );
      }
    }
    
    // Check for prompt injection attempts
    if (_containsPromptInjection(text)) {
      return InputFilterResult(
        isSafe: false,
        reason: 'Potential prompt injection detected',
      );
    }
    
    return InputFilterResult(
      isSafe: true,
      reason: 'Content passed pre-filter',
    );
  }

  /// Detect prompt injection attempts
  static bool _containsPromptInjection(String text) {
    final lowerText = text.toLowerCase();
    
    final injectionPatterns = [
      'ignore previous',
      'forget all',
      'system:',
      'you are now',
      'act as',
      'pretend to be',
      'disregard',
      'override',
    ];
    
    for (final pattern in injectionPatterns) {
      if (lowerText.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }
}

class InputFilterResult {
  final bool isSafe;
  final String reason;
  final String? blockedKeyword;

  InputFilterResult({
    required this.isSafe,
    required this.reason,
    this.blockedKeyword,
  });
}

