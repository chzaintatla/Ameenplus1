class SecurityUtils {
  SecurityUtils._();

  static String sanitizeInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:'), '')
        .replaceAll(RegExp(r'on\w+\s*='), '');
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  static String maskEmail(String email) {
    if (email.isEmpty) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final username = parts[0];
    final domain = parts[1];
    if (username.length <= 2) {
      return '${username[0]}***@$domain';
    }
    return '${username.substring(0, 2)}***@$domain';
  }

  static String maskPhoneNumber(String phone) {
    if (phone.length <= 4) return '****';
    return '${phone.substring(0, phone.length - 4)}****';
  }

  static Map<String, dynamic> filterSensitiveData(
    Map<String, dynamic> data,
    String currentUserId, {
    required bool isOwner,
    required bool isEmailPublic,
    required bool isPhonePublic,
    required bool isProfilePublic,
  }) {
    final filtered = Map<String, dynamic>.from(data);

    if (!isOwner) {
      if (!isProfilePublic) {
        return {
          'uid': data['uid'] ?? data['userId'],
          'displayName': data['displayName'] ?? 'User',
          'photoUrl': data['photoUrl'] ?? data['profilePicture'],
        };
      }

      if (!isEmailPublic) {
        filtered.remove('email');
      }

      if (!isPhonePublic) {
        filtered.remove('phoneNumber');
      }

      filtered.remove('birthday');
      filtered.remove('gender');
    }

    return filtered;
  }

  static bool isValidDisplayName(String name) {
    if (name.length < 2 || name.length > 50) return false;
    if (name.contains(RegExp(r'[<>{}[\]\\\/]'))) return false;
    return true;
  }

  static String validateAndSanitizeUrl(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return '';
    if (!['http', 'https'].contains(uri.scheme.toLowerCase())) return '';
    return uri.toString();
  }
}

