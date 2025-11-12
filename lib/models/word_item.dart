class WordItem {
  int? id;
  String word;
  String meaning;
  bool favorite;

  WordItem({
    this.id,
    required this.word,
    required this.meaning,
    this.favorite = false,
  });

  factory WordItem.fromJson(Map<String, dynamic> j) => WordItem(
        id: j['id'] as int?,
        word: (j['word'] ?? '').toString(),
        meaning: (j['meaning'] ?? '').toString(),
        favorite: (j['favorite'] ?? false) == true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) "id": id,
        "word": word,
        "meaning": meaning,
        "favorite": favorite,
      };
}
