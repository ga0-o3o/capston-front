// lib/pages/word/word_item.dart
class WordItem {
  int personalWordbookWordId;
  String word;
  List<String> wordKr;
  bool favorite;

  WordItem({
    required this.personalWordbookWordId,
    required this.word,
    required this.wordKr,
    this.favorite = false,
  });

  // JSON -> WordItem
  factory WordItem.fromJson(Map<String, dynamic> json) {
    return WordItem(
      personalWordbookWordId: json['personalWordbookWordId'] ?? 0,
      word: json['word'] ?? '',
      wordKr: List<String>.from(json['wordKr'] ?? []),
      favorite: json['favorite'] ?? false,
    );
  }

  // WordItem -> JSON
  Map<String, dynamic> toJson() {
    return {
      'personalWordbookWordId': personalWordbookWordId,
      'word': word,
      'wordKr': wordKr,
      'favorite': favorite,
    };
  }
}

class Issue {
  String wrongText;
  String message;

  Issue(this.wrongText, this.message);
}
