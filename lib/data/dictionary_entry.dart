class DictionaryEntry {
  DictionaryEntry(this.raw);
  final Map<String, dynamic> raw;
  int get id => raw['id'] as int? ?? 0;
  String get word => raw['word']?.toString() ?? '';
  String get letter => raw['letter']?.toString() ?? '';
  String get urdu => raw['urdu_meaning']?.toString() ?? '';
  String get english => raw['english_translation']?.toString() ?? '';
  String get wordNorm => raw['word_norm']?.toString() ?? '';
  List<String> get variantsNorm =>
      List<String>.from(raw['variants_norm'] ?? const []);
  List<String> get variants => List<String>.from(raw['variants'] ?? const []);
  String get urduNorm => raw['urdu_norm']?.toString() ?? '';
  String get englishNorm => raw['english_norm']?.toString() ?? '';
  List<String> get urduGlosses =>
      List<String>.from(raw['urdu_glosses_norm'] ?? const []);
  List<String> get englishGlosses =>
      List<String>.from(raw['english_glosses_norm'] ?? const []);
  List<List<String>> get englishGlossStems =>
      (raw['english_gloss_stems'] as List? ?? const [])
          .map((gloss) => List<String>.from(gloss as List))
          .toList();
  List<List<String>> get urduGlossTokens =>
      (raw['urdu_gloss_tokens'] as List? ?? const [])
          .map((gloss) => List<String>.from(gloss as List))
          .toList();
  String get wordLoose => raw['word_loose']?.toString() ?? '';
  List<String> get variantsLoose =>
      List<String>.from(raw['variants_loose'] ?? const []);
}

class Headword {
  Headword(this.entries);
  final List<DictionaryEntry> entries;
  DictionaryEntry get primary => entries.firstWhere(
    (entry) => entry.urdu.isNotEmpty || entry.english.isNotEmpty,
    orElse: () => entries.first,
  );
  String get word => primary.word;
  String get norm => primary.wordNorm;
  List<Map<String, String>> get senses {
    final seen = <String>{};
    return [
      for (final e in entries)
        if (seen.add('${e.urdu}\u0000${e.english}'))
          {'urdu': e.urdu, 'english': e.english},
    ];
  }
}
