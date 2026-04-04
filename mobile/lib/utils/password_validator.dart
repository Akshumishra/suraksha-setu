/// Reusable password strength validator for Suraksha Setu.
class PasswordValidator {
  PasswordValidator._();

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[!@#$%^&*()\-_=+\[\]{};:",.<>?/\\|`~]');

  /// Validates a password against strong password rules.
  /// Returns null if valid, or an error message string if invalid.
  static String? validate(String? value) {
    final p = value ?? '';
    if (p.isEmpty) return 'Password is required.';
    if (p.length < 8) return 'Password must be at least 8 characters.';
    if (!p.contains(_upper)) return 'Add at least one uppercase letter (A-Z).';
    if (!p.contains(_lower)) return 'Add at least one lowercase letter (a-z).';
    if (!p.contains(_digit)) return 'Add at least one number (0-9).';
    if (!p.contains(_special)) {
      return 'Add at least one special character (!@#\$% etc.).';
    }
    return null;
  }

  /// Returns a strength score from 0 (weak) to 4 (strong).
  static int strength(String value) {
    int score = 0;
    if (value.length >= 8) score++;
    if (value.contains(_upper) && value.contains(_lower)) score++;
    if (value.contains(_digit)) score++;
    if (value.contains(_special)) score++;
    return score;
  }

  /// Returns a human-readable label for the given strength score.
  static String strengthLabel(int score) {
    switch (score) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }
}
