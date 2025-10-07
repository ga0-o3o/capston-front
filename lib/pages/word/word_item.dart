// lib/pages/word/word_item.dart
class WordItem {
  int personalWordbookWordId;
  int personalWordbookId;
  String word;
  List<String> wordKr;
  bool favorite;
  String? groupId;

  WordItem({
    required this.personalWordbookWordId,
    required this.personalWordbookId,
    required this.word,
    required this.wordKr,
    this.favorite = false,
    this.groupId,
  });

  // JSON -> WordItem
  factory WordItem.fromJson(Map<String, dynamic> json) {
    return WordItem(
      personalWordbookWordId: json['personalWordbookWordId'] ?? 0,
      personalWordbookId: json['personalWordbookId'] ?? 0,
      word: json['word'] ?? '',
      wordKr: List<String>.from(json['wordKr'] ?? []),
      favorite: json['favorite'] ?? false,
      groupId: json['groupId'],
    );
  }

  // WordItem -> JSON
  Map<String, dynamic> toJson() {
    return {
      'personalWordbookWordId': personalWordbookWordId,
      'personalWordbookId': personalWordbookId,
      'word': word,
      'wordKr': wordKr,
      'favorite': favorite,
      'groupId': groupId,
    };
  }
}

class Issue {
  String wrongText;
  String message;

  Issue(this.wrongText, this.message);
}
