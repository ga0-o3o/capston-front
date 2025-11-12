// lib/pages/word/word_item.dart
class WordItem {
  int personalWordbookWordId;
  int personalWordbookId;
  String word;
  List<String> wordKr; // UI용 (중복 제거)
  List<String> wordKrOriginal; // 서버 원본 배열 (중복 포함, 퀴즈용)
  bool favorite;
  List<int> groupWordIds;

  WordItem({
    required this.personalWordbookWordId,
    required this.personalWordbookId,
    required this.word,
    required this.wordKr,
    List<String>? wordKrOriginal,
    this.favorite = false,
    List<int>? groupWordIds,
  })  : groupWordIds = groupWordIds ?? [personalWordbookWordId],
        wordKrOriginal = wordKrOriginal ?? List.from(wordKr);

  // ✅ copyWith 추가
  WordItem copyWith({
    int? personalWordbookWordId,
    int? personalWordbookId,
    String? word,
    List<String>? wordKr,
    List<String>? wordKrOriginal,
    bool? favorite,
    List<int>? groupWordIds,
  }) {
    return WordItem(
      personalWordbookWordId:
          personalWordbookWordId ?? this.personalWordbookWordId,
      personalWordbookId: personalWordbookId ?? this.personalWordbookId,
      word: word ?? this.word,
      wordKr: wordKr ?? this.wordKr,
      wordKrOriginal: wordKrOriginal ?? this.wordKrOriginal,
      favorite: favorite ?? this.favorite,
      groupWordIds: groupWordIds ?? this.groupWordIds,
    );
  }

  // JSON -> WordItem
  factory WordItem.fromJson(Map<String, dynamic> json) {
    final wordKrList = List<String>.from(json['wordKr'] ?? []);
    return WordItem(
      personalWordbookWordId: json['personalWordbookWordId'] ?? 0,
      personalWordbookId: json['personalWordbookId'] ?? 0,
      word: json['word'] ?? '',
      wordKr: wordKrList.toSet().toList(), // UI용
      wordKrOriginal: wordKrList, // 서버 원본
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
