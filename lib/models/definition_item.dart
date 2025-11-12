class DefinitionItem {
  String word;
  String meaning;
  String pos;
  String example;

  DefinitionItem({
    required this.word,
    required this.meaning,
    required this.pos,
    required this.example,
  });

  factory DefinitionItem.fromJson(Map<String, dynamic> j) => DefinitionItem(
        word: (j['word'] ?? '').toString(),
        meaning: (j['meaning'] ?? '').toString(),
        pos: (j['pos'] ?? '').toString(),
        example: (j['example'] ?? '').toString(),
      );

  Map<String, String> toMinJson() => {
        'word': word,
        'meaning': meaning,
      };
}
