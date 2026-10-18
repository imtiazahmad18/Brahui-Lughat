import 'dictionary_entry.dart';
import 'normalization.dart';
import 'urdu_collator.dart';

enum SearchMode { brahui, english, urdu }

class DictionarySearch {
  DictionarySearch(List<DictionaryEntry> entries) : entries = entries {
    final map = <String, List<DictionaryEntry>>{};
    for (final e in entries) {
      (map[e.wordNorm.isEmpty ? e.word : e.wordNorm] ??= []).add(e);
    }
    groups = map.values.map(Headword.new).toList();
  }
  final List<DictionaryEntry> entries;
  late final List<Headword> groups;
  List<SearchHit> search(String input, SearchMode mode) {
    var q = DictionaryNormalization.normalize(input);
    if (mode == SearchMode.english)
      q = q.replaceFirst(RegExp(r'^(to|a|an|the) '), '');
    if (q.isEmpty) return const [];
    final loose = DictionaryNormalization.normalize(input, loose: true);
    final hits = <SearchHit>[];
    for (final g in groups) {
      var best = 99;
      for (final e in g.entries) {
        if (mode == SearchMode.brahui) {
          final ws = [e.wordNorm, ...e.variantsNorm];
          if (ws.contains(q))
            best = _min(best, 1);
          else if (ws.any((s) => s.startsWith(q)))
            best = _min(best, 2);
          else if (ws.any((s) => s.contains(q) || s.split(' ').contains(q)))
            best = _min(best, 3);
          else if ([
            e.wordLoose,
            ...e.variantsLoose,
          ].any((s) => s == loose || s.startsWith(loose) || s.contains(loose)))
            best = _min(best, 4);
          else if (_fuzzyEligible(q) &&
              [
                e.wordNorm,
                ...e.variantsNorm,
              ].any((s) => _distance(q, s) <= _limit(q)))
            best = _min(best, 5);
          else if (e.urduNorm.contains(q) || e.englishNorm.contains(q))
            best = _min(best, 6);
        } else {
          final glosses = mode == SearchMode.english
              ? e.englishGlosses
              : e.urduGlosses;
          final whole = mode == SearchMode.english ? e.englishNorm : e.urduNorm;
          if (glosses.contains(q))
            best = _min(best, 1);
          else if (glosses.any((s) => s.startsWith(q)))
            best = _min(best, 2);
          else if (glosses.any(
            (s) =>
                s == q ||
                s.split(' ').contains(q) ||
                s.contains(' $q ') ||
                s.startsWith('$q ') ||
                s.endsWith(' $q'),
          ))
            best = _min(best, 3);
          else if (whole.contains(q))
            best = _min(best, 4);
          else if (_fuzzyEligible(q) &&
              glosses.any(
                (s) => s.split(' ').any((w) => _distance(q, w) <= _limit(q)),
              ))
            best = _min(best, 5);
        }
      }
      if (best < 99) hits.add(SearchHit(g, best));
    }
    hits.sort((a, b) {
      final t = a.tier.compareTo(b.tier);
      if (t != 0) return t;
      if (mode != SearchMode.brahui &&
          a.headword.entries.isNotEmpty &&
          b.headword.entries.isNotEmpty) {
        final x = _glossIndex(a.headword, q, mode);
        final y = _glossIndex(b.headword, q, mode);
        if (x != y) return x.compareTo(y);
      }
      final len = a.headword.word.runes.length.compareTo(
        b.headword.word.runes.length,
      );
      return len != 0
          ? len
          : UrduCollator.compare(a.headword.word, b.headword.word);
    });
    final kept = hits.where((h) => h.tier != 5).toList();
    kept.addAll(hits.where((h) => h.tier == 5).take(20));
    return kept;
  }

  static int _min(int a, int b) => a < b ? a : b;
  static int _glossIndex(Headword headword, String query, SearchMode mode) {
    var earliest = 999;
    for (final entry in headword.entries) {
      final glosses = mode == SearchMode.english
          ? entry.englishGlosses
          : entry.urduGlosses;
      final index = glosses.indexOf(query);
      if (index >= 0 && index < earliest) earliest = index;
    }
    return earliest;
  }

  static int _limit(String q) => q.runes.length <= 3
      ? 0
      : q.runes.length <= 5
      ? 1
      : 2;
  static bool _fuzzyEligible(String q) => q.runes.length >= 4;
  static int _distance(String a, String b) {
    final x = a.runes.toList(), y = b.runes.toList(), max = _limit(a);
    if ((x.length - y.length).abs() > max) return max + 1;
    var prev = List<int>.generate(y.length + 1, (i) => i),
        curr = List<int>.filled(y.length + 1, 0);
    for (var i = 1; i <= x.length; i++) {
      curr[0] = i;
      var rowMin = curr[0];
      for (var j = 1; j <= y.length; j++) {
        curr[j] = _min(
          _min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1),
        );
        if (curr[j] < rowMin) rowMin = curr[j];
      }
      if (rowMin > max) return max + 1;
      final swap = prev;
      prev = curr;
      curr = swap;
    }
    return prev[y.length];
  }
}
