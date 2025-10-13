// lib/pages/word/word_meaning.dart

class WordMeaning {
  final int wordId;
  final String wordKr;

  WordMeaning({
    required this.wordId,
    required this.wordKr,
  });

  // JSON -> WordMeaning
  factory WordMeaning.fromJson(Map<String, dynamic> json) {
    return WordMeaning(
      wordId: json['wordId'],
      wordKr: json['wordKr'],
    );
  }

  // WordMeaning -> JSON
  Map<String, dynamic> toJson() {
    return {
      'wordId': wordId,
      'wordKr': wordKr,
    };
  }
}
