/// Holds the full assessment result from DASS-21 and Headache questionnaires.
class AssessmentResult {
  // --- DASS-21 raw answers (index 0-20, value 0-3) ---
  final List<int> dass21Answers;

  // --- Headache info ---
  final String headacheType; // Tension / Migraine / Cluster / Other / None
  final String headacheFrequency; // Daily / Few times a week / Weekly / Monthly / Rarely
  final int headacheSeverity; // 1-10
  final String headacheDuration; // < 1 hour / 1-4 hours / 4-12 hours / > 12 hours

  const AssessmentResult({
    required this.dass21Answers,
    required this.headacheType,
    required this.headacheFrequency,
    required this.headacheSeverity,
    required this.headacheDuration,
  });

  // ---- DASS-21 subscale indices (0-based) ----
  // Depression : 2,4,9,12,15,16,20
  // Anxiety    : 1,3,6,8,14,18,19
  // Stress     : 0,5,7,10,11,13,17

  int get depressionScore {
    const idx = [2, 4, 9, 12, 15, 16, 20];
    return idx.fold(0, (sum, i) => sum + dass21Answers[i]) * 2;
  }

  int get anxietyScore {
    const idx = [1, 3, 6, 8, 14, 18, 19];
    return idx.fold(0, (sum, i) => sum + dass21Answers[i]) * 2;
  }

  int get stressScore {
    const idx = [0, 5, 7, 10, 11, 13, 17];
    return idx.fold(0, (sum, i) => sum + dass21Answers[i]) * 2;
  }

  // ---- Severity labels ----
  String get depressionLevel => _depressionLevel(depressionScore);
  String get anxietyLevel => _anxietyLevel(anxietyScore);
  String get stressLevel => _stressLevel(stressScore);

  static String _depressionLevel(int score) {
    if (score <= 9) return 'Normal';
    if (score <= 13) return 'Mild';
    if (score <= 20) return 'Moderate';
    if (score <= 27) return 'Severe';
    return 'Extremely Severe';
  }

  static String _anxietyLevel(int score) {
    if (score <= 7) return 'Normal';
    if (score <= 9) return 'Mild';
    if (score <= 14) return 'Moderate';
    if (score <= 19) return 'Severe';
    return 'Extremely Severe';
  }

  static String _stressLevel(int score) {
    if (score <= 14) return 'Normal';
    if (score <= 18) return 'Mild';
    if (score <= 25) return 'Moderate';
    if (score <= 33) return 'Severe';
    return 'Extremely Severe';
  }

  // ---- Headache severity label ----
  String get headacheSeverityLabel {
    if (headacheSeverity <= 3) return 'Mild';
    if (headacheSeverity <= 6) return 'Moderate';
    return 'Severe';
  }
}
