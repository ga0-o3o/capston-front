// lib/pages/word/word_item.dart
class WordItem {
  int personalWordbookWordId;
  int personalWordbookId;
  String word;
  List<String> wordKr;
  bool favorite;
  List<int> groupWordIds;

  WordItem({
    required this.personalWordbookWordId,
    required this.personalWordbookId,
    required this.word,
    required this.wordKr,
    this.favorite = false,
    List<int>? groupWordIds,
  }) : groupWordIds = groupWordIds ?? [personalWordbookWordId];

  // ✅ copyWith 추가
  WordItem copyWith({
    int? personalWordbookWordId,
    int? personalWordbookId,
    String? word,
    List<String>? wordKr,
    bool? favorite,
    List<int>? groupWordIds,
  }) {
    return WordItem(
      personalWordbookWordId:
          personalWordbookWordId ?? this.personalWordbookWordId,
      personalWordbookId: personalWordbookId ?? this.personalWordbookId,
      word: word ?? this.word,
      wordKr: wordKr ?? this.wordKr,
      favorite: favorite ?? this.favorite,
      groupWordIds: groupWordIds ?? this.groupWordIds,
    );
  }

  // JSON -> WordItem
  factory WordItem.fromJson(Map<String, dynamic> json) {
    return WordItem(
      personalWordbookWordId: json['personalWordbookWordId'] ?? 0,
      personalWordbookId: json['personalWordbookId'] ?? 0,
      word: json['word'] ?? '',
      wordKr: List<String>.from(json['wordKr'] ?? []),
      favorite: json['favorite'] ?? false,
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
    };
  }
}

class Issue {
  String wrongText;
  String message;

  Issue(this.wrongText, this.message);
}
