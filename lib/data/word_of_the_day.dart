import 'dictionary_entry.dart';

class WordOfTheDay {
  static DictionaryEntry? pick(List<DictionaryEntry> entries, DateTime date) {
    final eligible = entries
        .where(
          (e) =>
              e.urdu.isNotEmpty &&
              e.english.isNotEmpty &&
              e.raw['parent_id'] == null,
        )
        .toList();
    if (eligible.isEmpty) return null;
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    var hash = 0x811c9dc5;
    for (final codeUnit in stamp.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return eligible[hash % eligible.length];
  }
}
